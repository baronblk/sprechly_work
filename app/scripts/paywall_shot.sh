#!/usr/bin/env bash
#
# Captures the IAP review screenshot: the paywall with the product + live price
# (6,99 €). The price only renders when the app runs with a StoreKit
# configuration, which must sit in the scheme's *Test* action — XcodeGen only
# writes it into the Run action, so we patch the generated scheme here.
#
# Output: Screenshots/<lang>/<device>/iap-paywall.png
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="Screenshots"
OUT="Screenshots"
LANGS=(de en)
DEVICE_PATTERN="iPhone 17 Pro Max"
SCHEME_FILE="SprechlyWork.xcodeproj/xcshareddata/xcschemes/Screenshots.xcscheme"

xcodegen generate >/dev/null

# Inject the StoreKit config into the TestAction (idempotent).
python3 - "$SCHEME_FILE" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
ref = '      <StoreKitConfigurationFileReference\n         identifier = "../../Configuration/VoxStudio.storekit">\n      </StoreKitConfigurationFileReference>\n'
if "StoreKitConfigurationFileReference" not in s:
    s = s.replace("   </TestAction>", ref + "   </TestAction>", 1)
    open(p, "w").write(s)
    print("patched TestAction with StoreKit config")
else:
    print("StoreKit config already present")
PY

UDID="$(xcrun simctl list devices available | grep -E "$DEVICE_PATTERN" | grep -oE '[0-9A-Fa-f-]{36}' | head -1)"
NAME="$(xcrun simctl list devices available | grep -E "$DEVICE_PATTERN" | head -1 | sed -E 's/ *\(.*//' | xargs)"
[ -z "${UDID:-}" ] && { echo "No simulator: $DEVICE_PATTERN"; exit 1; }
echo "== $NAME ($UDID) =="
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true

xcodebuild build-for-testing -project SprechlyWork.xcodeproj -scheme "$SCHEME" \
  -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO >/dev/null

for lang in "${LANGS[@]}"; do
  echo "   -> $lang"
  RB="$(mktemp -d)/r.xcresult"
  TEST_RUNNER_SCREENSHOT_LANG="$lang" xcodebuild test-without-building -project SprechlyWork.xcodeproj -scheme "$SCHEME" \
    -only-testing:VoxStudioUITests/ScreenshotTests/testPaywall \
    -destination "id=$UDID" -resultBundlePath "$RB" CODE_SIGNING_ALLOWED=NO >/dev/null
  EX="$(mktemp -d)"
  xcrun xcresulttool export attachments --path "$RB" --output-path "$EX" >/dev/null
  DEST="$OUT/$lang/$NAME"; mkdir -p "$DEST"
  python3 - "$EX" "$DEST" "$lang" <<'PY'
import json, os, re, shutil, sys
ex, dest, lang = sys.argv[1], sys.argv[2], sys.argv[3]
m = json.load(open(os.path.join(ex, "manifest.json")))
for t in m:
    for a in t.get("attachments", []):
        n = a.get("suggestedHumanReadableName") or ""
        mt = re.match(rf"{lang}-((?:\d+|iap)-[a-z]+)", n)
        if n.endswith(".png") and mt:
            shutil.copy(os.path.join(ex, a["exportedFileName"]), os.path.join(dest, mt.group(1) + ".png"))
            print("      ", os.path.join(dest, mt.group(1) + ".png"))
PY
done
echo "Done."
