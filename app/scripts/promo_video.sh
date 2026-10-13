#!/usr/bin/env bash
#
# Builds a professional vertical (1080x1920, 9:16) social promo video for
# TikTok / Reels / Shorts from REAL app footage:
#   branded intro card -> live app b-roll (playback cursor, scrolling) with
#   animated value-prop captions -> CTA outro card, with crossfades.
#
# Pipeline: render brand overlays (CoreGraphics) -> record the paced PromoFlowTest
# on the 6.9" simulator -> compose with ffmpeg. Audio is intentionally dropped —
# add licensed music in the TikTok/Reels editor.
#
# Output: Screenshots/video/promo-<lang>.mp4
# Usage:  scripts/promo_video.sh [de|en]
set -euo pipefail
cd "$(dirname "$0")/.."

LANG_CODE="${1:-de}"
SCHEME="Screenshots"
OUT="Screenshots/video"
DEVICE_PATTERN="iPhone 17 Pro Max"
ASSETS="$(mktemp -d)"
WORK="$(mktemp -d)"
trap 'rm -rf "$ASSETS" "$WORK"' EXIT

command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg required (brew install ffmpeg)"; exit 1; }
mkdir -p "$OUT"

echo "== brand overlays ($LANG_CODE) =="
swift scripts/promo_assets.swift "$LANG_CODE" "$ASSETS" >/dev/null

xcodegen generate >/dev/null
UDID="$(xcrun simctl list devices available | grep -E "$DEVICE_PATTERN" | grep -oE '[0-9A-Fa-f-]{36}' | head -1)"
[ -z "${UDID:-}" ] && { echo "No simulator matching: $DEVICE_PATTERN"; exit 1; }
echo "== $DEVICE_PATTERN ($UDID) =="
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" >/dev/null 2>&1 || true
xcodebuild build-for-testing -project SprechlyWork.xcodeproj -scheme "$SCHEME" \
  -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO >/dev/null

echo "== record app b-roll =="
RAW="$WORK/raw.mp4"
xcrun simctl io "$UDID" recordVideo --codec h264 --force "$RAW" &
REC_PID=$!
sleep 1
TEST_RUNNER_SCREENSHOT_LANG="$LANG_CODE" xcodebuild test-without-building -project SprechlyWork.xcodeproj -scheme "$SCHEME" \
  -only-testing:VoxStudioUITests/PromoFlowTest \
  -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO >/dev/null 2>&1 || true
sleep 1
kill -INT "$REC_PID" 2>/dev/null || true
wait "$REC_PID" 2>/dev/null || true

# --- compose ---------------------------------------------------------------
# Trim the launch run-up, then frame full-bleed 1080x1920.
LEAD=8        # seconds skipped (test-runner spin-up + app cold launch)
BODY=15       # seconds of app footage used
echo "== compose body + captions =="
# value-prop caption windows (start dur) within the BODY timeline
CAP_START=(0.5 4.2 8.2 12.0)
CAP_DUR=(3.4 3.4 3.4 3.0)

inputs=(-ss "$LEAD" -t "$BODY" -i "$RAW")
# setsar=1 is required before xfade — the cropped recording carries a non-1 SAR
# that otherwise makes xfade emit a near-empty clip.
fc="[0:v]scale=1080:-2,crop=1080:1920:(iw-1080)/2:(ih-1920)/2,fps=30,setsar=1,format=yuv420p[base];"
prev="base"
for i in 0 1 2 3; do
  n=$((i + 1)); s="${CAP_START[$i]}"; d="${CAP_DUR[$i]}"
  fo=$(awk "BEGIN{print $d-0.3}")
  inputs+=(-loop 1 -t "$d" -i "$ASSETS/cap$n.png")
  fc+="[$n:v]format=yuva420p,fade=t=in:st=0:d=0.3:alpha=1,fade=t=out:st=$fo:d=0.3:alpha=1,setpts=PTS+$s/TB[c$n];"
  fc+="[$prev][c$n]overlay=eof_action=pass:repeatlast=0[b$n];"
  prev="b$n"
done
fc="${fc%;}"
ffmpeg -nostdin -loglevel error "${inputs[@]}" -filter_complex "$fc" -map "[$prev]" \
  -r 30 -c:v libx264 -profile:v high -pix_fmt yuv420p -b:v 12M -an "$WORK/body.mp4" -y

echo "== intro / outro cards =="
ffmpeg -nostdin -loglevel error -loop 1 -t 1.8 -i "$ASSETS/intro.png" \
  -vf "scale=1080:1920,fps=30,fade=t=in:st=0:d=0.4,fade=t=out:st=1.4:d=0.4,format=yuv420p" \
  -r 30 -c:v libx264 -pix_fmt yuv420p -an "$WORK/intro.mp4" -y
ffmpeg -nostdin -loglevel error -loop 1 -t 2.8 -i "$ASSETS/outro.png" \
  -vf "scale=1080:1920,fps=30,fade=t=in:st=0:d=0.4,fade=t=out:st=2.4:d=0.4,format=yuv420p" \
  -r 30 -c:v libx264 -pix_fmt yuv420p -an "$WORK/outro.mp4" -y

echo "== stitch (crossfades) =="
FINAL="$OUT/promo-$LANG_CODE.mp4"
ffmpeg -nostdin -loglevel error -i "$WORK/intro.mp4" -i "$WORK/body.mp4" -i "$WORK/outro.mp4" \
  -filter_complex "[0:v]setsar=1[i];[1:v]setsar=1[b];[2:v]setsar=1[o];[i][b]xfade=transition=fade:duration=0.4:offset=1.4[a];[a][o]xfade=transition=fade:duration=0.4:offset=16.0[v]" \
  -map "[v]" -r 30 -c:v libx264 -profile:v high -pix_fmt yuv420p -b:v 12M -movflags +faststart "$FINAL" -y

DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$FINAL" 2>/dev/null || echo "?")
echo "Done -> $FINAL  (1080x1920, 30 fps, ~${DUR}s, silent)"
echo "Add licensed music in the TikTok/Reels editor."
