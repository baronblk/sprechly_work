#!/bin/bash
# Baut Sprechly Work signiert, prüft die Identität, installiert aufs iPhone und
# startet die App. Ersetzt die vier Handgriffe aus DEPLOY.md.
#
#   ./scripts/deploy.sh              # erstes verfügbares physisches Gerät
#   ./scripts/deploy.sh <UDID>       # ein bestimmtes Gerät
#
# Das iPhone muss entsperrt und dem Mac vertraut sein.
set -euo pipefail

cd "$(dirname "$0")/.."

BUNDLE_ID="de.gcng.sprechly.work"
TEAM="KZFCCDV6A8"
APP=".derivedData/Build/Products/Debug-iphoneos/SprechlyWork.app"

fehler() { printf '\033[31m✗ %s\033[0m\n' "$1" >&2; exit 1; }
schritt() { printf '\033[1m→ %s\033[0m\n' "$1"; }

# --- Gerät bestimmen ---------------------------------------------------------
udid="${1:-}"
if [[ -z "$udid" ]]; then
    udid=$(xcrun devicectl list devices 2>/dev/null \
        | awk '/physical/ && /available/ { for (i = 1; i <= NF; i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) { print $i; exit } }')
    [[ -n "$udid" ]] || fehler "kein verbundenes iPhone gefunden – UDID als Argument übergeben"
fi
schritt "Gerät $udid"

# --- Projekt erzeugen --------------------------------------------------------
# Pflicht: die .xcodeproj ist gitignored und listet Dateien explizit. Ohne das
# fehlen neu angelegte Dateien im Target – und Tests laufen stillschweigend nicht.
command -v xcodegen >/dev/null || fehler "xcodegen fehlt (brew install xcodegen)"
schritt "Xcode-Projekt erzeugen"
xcodegen generate >/dev/null

# --- Bauen -------------------------------------------------------------------
# Generisch bauen, nicht gegen das Gerät: Sonst wartet xcodebuild darauf, dass
# das iPhone erreichbar ist, und bricht ab, während es noch verbindet. Zum Bauen
# wird es nicht gebraucht – erst zum Installieren.
schritt "signiert bauen"
xcodebuild -project SprechlyWork.xcodeproj -scheme SprechlyWork \
    -destination "generic/platform=iOS" -derivedDataPath .derivedData \
    -allowProvisioningUpdates build >/tmp/sprechlywork-build.log 2>&1 \
    || { tail -40 /tmp/sprechlywork-build.log >&2; fehler "Build fehlgeschlagen (volles Protokoll: /tmp/sprechlywork-build.log)"; }

[[ -d "$APP" ]] || fehler "kein Build unter $APP"

# --- Identität gegenprüfen ---------------------------------------------------
# Fängt einen Build ab, der noch die Kennung der Store-App trägt: der würde auf
# deren iCloud-Daten zugreifen.
schritt "Identität prüfen"
rechte=$(codesign -d --entitlements - "$APP" 2>/dev/null || true)
grep -q "$TEAM.$BUNDLE_ID" <<<"$rechte" \
    || fehler "application-identifier ist nicht $TEAM.$BUNDLE_ID"
if grep -oE 'de\.gcng\.sprechly[a-z.]*' <<<"$rechte" | grep -qv '^de\.gcng\.sprechly\.work'; then
    fehler "Build trägt eine Kennung der Store-App – Abbruch"
fi
echo "   application-identifier $TEAM.$BUNDLE_ID"

# --- Installieren und starten ------------------------------------------------
# Das iPhone kann noch beim Verbinden sein – besonders direkt nach einem
# abgebrochenen Build braucht der Gerätedienst eine Weile. Deshalb nachfassen,
# und bei endgültigem Fehlschlag den Grund von devicectl zeigen statt eine
# geratene Vermutung.
schritt "installieren"
protokoll=$(mktemp -t sprechlywork-install)
for versuch in $(seq 1 10); do
    if xcrun devicectl device install app --device "$udid" "$APP" >"$protokoll" 2>&1; then
        installiert=1; break
    fi
    echo "   Gerät nicht erreichbar – Versuch $versuch/10"
    sleep 6
done
if [[ -z "${installiert:-}" ]]; then
    grep -iE "error|failed|unable" "$protokoll" | tail -3 >&2 || true
    rm -f "$protokoll"
    fehler "Installation fehlgeschlagen – iPhone verbunden und entsperrt?"
fi
rm -f "$protokoll"

schritt "starten"
for versuch in $(seq 1 8); do
    if xcrun devicectl device process launch --device "$udid" "$BUNDLE_ID" >/dev/null 2>&1; then
        gestartet=1; break
    fi
    echo "   iPhone gesperrt – entsperren, Versuch $versuch/8"
    sleep 10
done
[[ -n "${gestartet:-}" ]] || fehler "Start fehlgeschlagen (iPhone entsperren und erneut versuchen)"

# --- Ablaufdatum melden ------------------------------------------------------
# Darüber hinaus startet die App nicht mehr; dann genügt ein erneuter Lauf.
profil="$APP/embedded.mobileprovision"
if [[ -f "$profil" ]]; then
    plist=$(mktemp -t sprechlywork-profil)
    if security cms -D -i "$profil" >"$plist" 2>/dev/null; then
        ablauf=$(/usr/libexec/PlistBuddy -c "Print :ExpirationDate" "$plist" 2>/dev/null || true)
        [[ -n "$ablauf" ]] && printf '\033[32m✓ installiert und gestartet – Signatur gültig bis %s\033[0m\n' "$ablauf"
    fi
    rm -f "$plist"
else
    printf '\033[32m✓ installiert und gestartet\033[0m\n'
fi
