#!/usr/bin/env python3
"""Locates the preview scenes inside a raw simulator recording.

`PreviewFlowTest` prints a `PREVIEWMARK <name> <epoch>` line as each scene
begins. This reads those marks out of the xcodebuild log and converts them to
positions in the recording: one `<start> <duration>` line per scene, which
`preview_video.sh` turns into one independently seeked ffmpeg input each.

An earlier version emitted a single filter graph that split the decoded stream
and trimmed five branches out of it. It worked and it was unusable: `concat`
wants the first scene while `split` is already feeding it the fifth, so every
frame in between is buffered. Twenty-one minutes and 1.8 GB in, it had still
not finished. Seeking five inputs separately keeps memory flat and the encode
under a minute.

Why cut at all: a single take of the walkthrough runs about 46 seconds, and
roughly twenty of those are XCUITest moving between scenes — waiting for the
app to go quiescent, and sitting on the detail view for about three seconds
after each sheet is dismissed. Those are not pauses the test asks for, so they
cannot be shortened in the test. Cutting them out is the only way to get 28
seconds that are all scene.

The marks are wall-clock, but they are only ever used relative to the `launch`
mark, so the lag between starting the screen recording and the app appearing
never enters the arithmetic. `launch` itself is pinned to the first frame on
which the app was actually on screen, measured from the video by
`find_app_session.py`.

Usage: find_preview_scenes.py <marks-log> <session-start-seconds>
"""
from __future__ import annotations

import pathlib
import re
import sys

# The storyboard, in order, as (mark, seconds taken from it). Sums to 28.0 —
# the finished preview's length, and the figure the shell asserts afterwards.
SCENES: list[tuple[str, float]] = [
    ("recording", 8.0),    # scenes 1-2: the timer running and the waveform moving
    ("transcript", 5.5),   # scene 3: the finished transcript with timestamps
    ("summary", 5.5),      # scene 4: the AI summary
    ("translation", 5.0),  # scene 5: the stored translation
    ("library", 4.0),      # scene 6: the library, under the closing line
]
# Dropped from the front of every scene. It covers the constant error between
# the `launch` mark and the frame the app actually appeared on: the mark is
# taken in the test process, the frame is measured in the video, and they
# cannot be made to coincide. Measured at 1.9 s with the mark placed after the
# first element query and smaller with it placed before, so two seconds puts
# every slice inside its scene. The test holds each scene 2.5 s longer than its
# slice to absorb the same error from the other side.
SETTLE = 2.0


def read_marks(path: pathlib.Path) -> dict[str, float]:
    marks: dict[str, float] = {}
    pattern = re.compile(r"PREVIEWMARK\s+(\w+)\s+([0-9.]+)")
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        found = pattern.search(line)
        if found:
            # First occurrence wins: xcodebuild echoes the runner's stdout in
            # more than one place.
            marks.setdefault(found.group(1), float(found.group(2)))
    return marks


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: find_preview_scenes.py <marks-log> <session-start>",
              file=sys.stderr)
        return 2

    marks = read_marks(pathlib.Path(sys.argv[1]))
    session_start = float(sys.argv[2])

    missing = [name for name, _ in [("launch", 0.0)] + SCENES
               if name not in marks]
    if missing:
        print(f"missing scene marks in the test log: {', '.join(missing)}",
              file=sys.stderr)
        return 1

    launch = marks["launch"]

    for name, length in SCENES:
        start = session_start + (marks[name] - launch) + SETTLE
        print(f"      {name:<12} {start:7.3f}s + {length:4.1f}s", file=sys.stderr)
        print(f"{start:.3f} {length:.3f}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
