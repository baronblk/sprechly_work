#!/usr/bin/env bash
#
# Records App Store **app preview** videos: runs the paced PreviewFlowTest while
# capturing the simulator screen, then cuts the six scenes together.
#
# Output: Screenshots/video/preview-<lang>.mp4
#         886x1920, H.264 High 4.0, yuv420p, 30 fps, 28.000 s, silent AAC
#         stereo 48 kHz.
#
# 886x1920 is Apple's accepted preview resolution for iPhone with Dynamic
# Island. The simulator records at the *device* resolution 1320x2868, which
# Apple lists for reference only and does not accept as a preview — the videos
# from 21.06.2026 used it and would likely have been rejected. The scale/crop
# in the filter graph below is what makes the output a valid size, so do not
# remove it.
#
# Full write-up, including the pitfalls this chain works around:
# docs/aso/PREVIEW_VIDEO.md
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="Screenshots"
OUT="Screenshots/video"
# One language at a time: the pilot is produced and reviewed before the rest.
LANGS=(${PREVIEW_LANGS:-de})
DEVICE_PATTERN="iPhone 17 Pro Max"

xcodegen generate >/dev/null
mkdir -p "$OUT"

UDID="$(xcrun simctl list devices available | grep -E "$DEVICE_PATTERN" | grep -oE '[0-9A-Fa-f-]{36}' | head -1)"
[ -z "${UDID:-}" ] && { echo "No simulator matching: $DEVICE_PATTERN"; exit 1; }
echo "== $DEVICE_PATTERN ($UDID) =="
# Fresh boot plus a fixed status bar, same as scripts/screenshots.sh. Without
# it the video carries the capture machine's real clock and, after another app
# has run on this simulator, a "< OtherApp" breadcrumb.
xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true
xcrun simctl privacy "$UDID" grant microphone de.gcng.sprechly >/dev/null 2>&1 || true
xcrun simctl status_bar "$UDID" override \
  --time "09:41" \
  --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 \
  --batteryState charged --batteryLevel 100 >/dev/null 2>&1 || true

xcodebuild build-for-testing -project SprechlyWork.xcodeproj -scheme "$SCHEME" \
  -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO >/dev/null

for lang in "${LANGS[@]}"; do
  echo "   -> $lang"
  VIDEO="$OUT/preview-$lang.mp4"
  RAW="$OUT/.raw-$lang.mp4"
  rm -f "$VIDEO" "$RAW"
  xcrun simctl io "$UDID" recordVideo --codec h264 --force "$RAW" &
  REC_PID=$!
  sleep 1
  # Kept, not discarded: PreviewFlowTest prints a PREVIEWMARK line as each
  # scene begins and the cut below is built from them.
  MARKS="$(mktemp -t preview-marks)"

  # Scene 1-2 has to show the waveform moving, and it only moves if the
  # microphone hears something. The simulator records through the Mac's input
  # device, so a sentence spoken out of the Mac's speakers reaches it the
  # ordinary acoustic way — speaker, air, built-in microphone. No loopback
  # device, nothing about the audio configuration changed. AudioSessionController
  # runs the session in .default mode, so there is no echo cancellation to
  # subtract the speaker again.
  #
  # The line is the neutral sprint-planning text the asset spec already uses,
  # so nothing private is spoken and the take matches the rest of the set.
  #
  # Triggered off the test's own `recording` mark rather than a guessed offset,
  # and killed afterwards. This signal exists only to move the waveform: the
  # finished preview carries the silent AAC track built further down, and the
  # microphone never reaches it.
  case "$lang" in
    de) SPEAK_VOICE="Anna"
        SPEAK_LINE="Lass uns mit der Sprint-Planung starten. Oberste Priorität ist das neue Onboarding. Design liefert die Screens bis Mittwoch, dann übernimmt die Entwicklung." ;;
    *)  SPEAK_VOICE="Samantha"
        SPEAK_LINE="Let's start with sprint planning. Top priority is the new onboarding. Design delivers the screens by Wednesday, then engineering takes over." ;;
  esac
  (
    DEADLINE=$((SECONDS + 180))
    until grep -q "PREVIEWMARK recording" "$MARKS" 2>/dev/null; do
      [ "$SECONDS" -gt "$DEADLINE" ] && exit 0
      sleep 0.1
    done
    say -v "$SPEAK_VOICE" "$SPEAK_LINE" 2>/dev/null || true
  ) &
  SPEAK_PID=$!
  TEST_RUNNER_SCREENSHOT_LANG="$lang" xcodebuild test-without-building -project SprechlyWork.xcodeproj -scheme "$SCHEME" \
    -only-testing:VoxStudioUITests/PreviewFlowTest \
    -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO >"$MARKS" 2>&1 || true
  kill "$SPEAK_PID" 2>/dev/null || true
  wait "$SPEAK_PID" 2>/dev/null || true
  sleep 1
  kill -INT "$REC_PID" 2>/dev/null || true
  wait "$REC_PID" 2>/dev/null || true

  if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "      ⚠️  ffmpeg not found — $VIDEO is the raw recording, unusable as a preview"
    continue
  fi

  # Closing line, scene 6 only. Over real app footage, not a separate card:
  # Apple expects a preview to be mostly captured app material.
  #
  # Rendered to a PNG by Pillow and composited, because the ffmpeg here is
  # built without libfreetype and has no drawtext filter. The store screenshots
  # already caption through Pillow, so this is one text path, not two.
  OVERLAY="$(mktemp -t preview-overlay).png"
  python3 scripts/make_preview_overlay.py "$lang" 886 1920 "$OVERLAY" >/dev/null

  # fps=30 belongs in the graph, not in a -r 30 output option. simctl records
  # variable-frame-rate and leaves no frames at all while the screen is static
  # — gaps of up to 5.5 s. -r 30 only sets the encoder's rate and dropped those
  # gaps instead of filling them, turning a 22 s cut into 17.7 s and pushing
  # the closing overlay past the end. The fps filter duplicates across a gap,
  # which is what a constant-frame-rate preview needs.
  #
  # The cut is anchored on the START of the app session, found by luma (see
  # scripts/find_app_session.py). Anchoring on the end cannot work: the
  # recording opens with 15-45 s of home screen while the test runner installs,
  # so the last 28 seconds are not the app's last 28 seconds.
  #
  # Within the session the six scenes are located by the marks the test printed
  # and cut together, dropping what lies between them. A single take runs about
  # 46 s, of which roughly twenty are XCUITest getting from one scene to the
  # next — quiescence waits, and about three seconds sitting on the detail view
  # after every sheet is dismissed. Those are not pauses the test asks for and
  # cannot be shortened there, so they come out here instead. Every remaining
  # frame is still captured app footage.
  read -r SESSION_START SESSION_END < <(python3 -I scripts/find_app_session.py "$RAW")
  echo "      app on screen ${SESSION_START}s-${SESSION_END}s"

  # Normalise once, cut afterwards. The raw file is variable-frame-rate with
  # multi-second gaps wherever the screen is static, and seeking into it does
  # not land where it claims to — frames sampled through -ss disagreed with the
  # same frames decoded in sequence. After fps=30 the timeline is constant and
  # a seek means what it says.
  NORM="$OUT/.norm-$lang.mp4"
  ffmpeg -nostdin -loglevel error -i "$RAW" \
    -vf "scale=886:-2,crop=886:1920:0:0,fps=30" \
    -c:v libx264 -preset veryfast -crf 16 -pix_fmt yuv420p -an "$NORM" -y

  # One pass, no concatenation. The scenes appear in the recording in the order
  # the story needs them, so select can pick the five windows as they stream by
  # and setpts renumbers the kept frames into a continuous 30 fps timeline.
  # Both alternatives were built and measured first: split/trim/concat over one
  # input, and five separately seeked inputs joined by concat. Each buffers
  # every frame between the first scene and the last — 1.8 to 2.1 GB, still
  # running after twenty minutes. This finishes in about five seconds.
  #
  # Every input is bounded. The still image feeding the overlay is a -loop 1
  # input, which produces frames forever: left unbounded it floods the filter
  # queue while the video input is still being decoded, which is what made the
  # earlier attempts look like a concat problem.
  SELECT=""
  TOTAL=0
  while read -r SEG_START SEG_LEN; do
    SEG_END="$(python3 -c "print(round($SEG_START + $SEG_LEN, 3))")"
    [ -n "$SELECT" ] && SELECT="${SELECT}+"
    SELECT="${SELECT}between(t\,${SEG_START}\,${SEG_END})"
    TOTAL="$(python3 -c "print(round($TOTAL + $SEG_LEN, 3))")"
  done < <(python3 -I scripts/find_preview_scenes.py "$MARKS" "$SESSION_START")
  if [ -z "$SELECT" ]; then
    echo "      FEHLER: Szenenmarken fehlen, Schnitt nicht möglich" >&2
    exit 1
  fi
  OVERLAY_FROM="$(python3 -c "print(round($TOTAL - 3.0, 3))")"

  # Built as one unbroken string: a backslash-newline inside a filter graph
  # silently ate ":e" out of "start=..:end=.." and ffmpeg then complained about
  # an unparsable duration.
  FILTER="[0:v]select='${SELECT}',setpts=N/(30*TB)[cat]"
  FILTER="${FILTER};[cat][1:v]overlay=0:0:enable='between(t,${OVERLAY_FROM},${TOTAL})'[v]"
  #
  # 886x1920 is Apple's accepted preview resolution for iPhone with Dynamic
  # Island (large display). 1320x2868 is the *device* resolution, listed for
  # reference only — the previous videos used it and would not have passed.
  #
  # The audio track is deliberately present but silent: Apple documents the
  # audio format (stereo, 256 kbps AAC, 44.1/48 kHz, "all tracks should be
  # enabled") without saying whether a track is required, so carrying a valid
  # silent one is the safe reading.
  ffmpeg -nostdin -loglevel error \
    -i "$NORM" \
    -framerate 30 -loop 1 -t "$TOTAL" -i "$OVERLAY" \
    -f lavfi -t "$TOTAL" -i anullsrc=channel_layout=stereo:sample_rate=48000 \
    -filter_complex "$FILTER" \
    -map "[v]" -map 2:a -t "$TOTAL" \
    -c:v libx264 -profile:v high -level 4.0 -pix_fmt yuv420p \
    -b:v 11M -maxrate 12M -bufsize 24M \
    -c:a aac -b:a 256k -ar 48000 -ac 2 \
    "$VIDEO.out.mp4" -y && mv "$VIDEO.out.mp4" "$VIDEO"

  # Fail loudly instead of shipping a video the storyboard does not fit into:
  # the closing overlay sits at 25-28 s, so a short cut silently drops it.
  OUT_DUR="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$VIDEO")"
  if ! python3 -c "import sys; sys.exit(0 if abs($OUT_DUR - 28.0) <= 0.2 else 1)"; then
    echo "      FEHLER: ${OUT_DUR}s statt 28 s — Overlay-Fenster 25-28 s nicht abgedeckt" >&2
    exit 1
  fi
  rm -f "$OVERLAY" "$MARKS" "$NORM"

  echo "      $VIDEO"
done

echo "Done. See $OUT/ (886x1920, 30 fps, 28 s, silent AAC stereo)"
