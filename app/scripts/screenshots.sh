#!/usr/bin/env bash
#
# Generates App Store screenshots from seeded demo data (DemoSeed / SEED_DEMO)
# on the required device sizes (6.9" iPhone + 13" iPad) in German and English.
#
# Output: Screenshots/<lang>/<device>/NN-screen.png
#
# Requires the simulators to exist (Xcode → Settings → Components, or default
# set). Run from anywhere: scripts/screenshots.sh
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="Screenshots"
OUT="Screenshots"
LANGS=(de en)
# App Store requires a 6.9" iPhone and a 13" iPad screenshot set.
DEVICE_PATTERNS=("iPhone 17 Pro Max" "iPad Pro 13-inch")

xcodegen generate >/dev/null

# Picks a simulator by name *and* runtime: matching on the name alone picks up
# older-iOS devices (an iOS 18 iPad shadowed the iOS 26 one here), which then
# fail the deployment target. Prints "<udid>\t<name>".
device_for() {
  xcrun simctl list devices available --json | python3 -c '
import json, re, sys
pattern, minimum = sys.argv[1], 26
data = json.load(sys.stdin)["devices"]
best = None
for runtime, devices in data.items():
    m = re.search(r"iOS[-.](\d+)[-.](\d+)", runtime)
    if not m:
        continue
    version = (int(m.group(1)), int(m.group(2)))
    if version[0] < minimum:
        continue
    for device in devices:
        if not device.get("isAvailable"):
            continue
        if re.search(pattern, device["name"]):
            # Prefer the newest runtime, and a plain name over a renamed clone.
            rank = (version, -len(device["name"]))
            if best is None or rank > best[0]:
                best = (rank, device["udid"], device["name"])
if best:
    print(f"{best[1]}\t{best[2]}")
' "$1"
}

for pat in "${DEVICE_PATTERNS[@]}"; do
  FOUND="$(device_for "$pat" || true)"
  if [ -z "${FOUND:-}" ]; then echo "⚠️  No available iOS 26+ simulator matching: $pat — skipping"; continue; fi
  UDID="${FOUND%%	*}"
  NAME="${FOUND##*	}"
  echo "== $NAME ($UDID) =="
  # Boot fresh **once per device**, before the build. A leftover foreground app
  # makes iOS draw a "< OtherApp" breadcrumb into the status bar, which would
  # put a foreign app's name on our store screenshot. Doing this per language
  # instead left the iPad test runner hanging for its full 600 s timeout, so it
  # belongs here and only here.
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true
  # The in-progress recording shot needs the mic, otherwise the run stalls on
  # the permission alert and the waveform stays flat.
  xcrun simctl privacy "$UDID" grant microphone de.gcng.sprechly >/dev/null 2>&1 || true
  # One identical status bar for every shot, instead of the host's real clock.
  xcrun simctl status_bar "$UDID" override \
    --time "09:41" \
    --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 \
    --batteryState charged --batteryLevel 100 >/dev/null 2>&1 || true
  xcodebuild build-for-testing -project SprechlyWork.xcodeproj -scheme "$SCHEME" \
    -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO >/dev/null

  for lang in "${LANGS[@]}"; do
    echo "   -> $lang"
    RB="$(mktemp -d)/r.xcresult"
    # TEST_RUNNER_ prefix is the only env that xcodebuild forwards to the runner.
    # Marketing set only (record/library/detail/transcript). The paywall is the
    # IAP review screenshot — generated separately by scripts/paywall_shot.sh so
    # its StoreKit-test price doesn't end up on a store marketing screenshot.
    TEST_RUNNER_SCREENSHOT_LANG="$lang" xcodebuild test-without-building -project SprechlyWork.xcodeproj -scheme "$SCHEME" \
      -only-testing:VoxStudioUITests/ScreenshotTests/testCaptureScreenshots \
      -destination "id=$UDID" -resultBundlePath "$RB" CODE_SIGNING_ALLOWED=NO >/dev/null
    EX="$(mktemp -d)"
    xcrun xcresulttool export attachments --path "$RB" --output-path "$EX" >/dev/null
    # Folder named after the pattern, not the concrete device: the simulator
    # gains a new generation suffix with every Xcode release, and the store set
    # should not move with it.
    DEST="$OUT/$lang/$pat"; mkdir -p "$DEST"
    python3 - "$EX" "$DEST" "$lang" <<'PY'
import json, os, re, shutil, sys
ex, dest, lang = sys.argv[1], sys.argv[2], sys.argv[3]
manifest = json.load(open(os.path.join(ex, "manifest.json")))
for test in manifest:
    for att in test.get("attachments", []):
        name = att.get("suggestedHumanReadableName") or ""
        m = re.match(rf"{lang}-((?:\d+|iap)-[a-z]+)", name)
        if name.endswith(".png") and m:
            shutil.copy(os.path.join(ex, att["exportedFileName"]),
                        os.path.join(dest, m.group(1) + ".png"))
            print("      ", os.path.join(dest, m.group(1) + ".png"))
PY
  done
done
echo "Done. See $OUT/"
