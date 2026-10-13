#!/usr/bin/env python3
"""Finds where the app was on screen in a raw simulator recording.

`scripts/preview_video.sh` records the whole simulator session, which begins
with the home screen and the test runner installing, and ends with the home
screen again after XCUITest terminates the app. The preview must contain
neither. Cutting a fixed number of seconds off the end does not work: the
install takes anywhere from 25 to 45 seconds, so the app's position in the
recording moves between runs.

Sprechly is dark-first, the home screen is not. Measured over a real recording
the separation is absolute — the app sits at an average luma of 37-46, the home
screen at 157-169, the launch screen at 232 — so the app session is simply the
longest dark stretch.

Prints "<start> <end>" in seconds.
"""
from __future__ import annotations

import re
import subprocess
import sys

# The app never came near this and the home screen never came near it from
# below; anything in between would be a launch screen or a transition.
DARK_MAX_LUMA = 90.0
# Sampling rate for the luma series. Four per second puts the anchor within a
# quarter second, which is finer than any scene boundary in the flow.
SAMPLES_PER_SECOND = 4
# A run shorter than this is a transition or a dropped frame, not the session.
MIN_SESSION_SECONDS = 15.0


def luma_series(path: str) -> list[tuple[float, float]]:
    """Returns (timestamp, average luma) sampled through the whole recording.

    Decoded straight through rather than seeked: the recordings are
    variable-frame-rate with multi-second gaps wherever the screen is static,
    and seeking into them does not land where it claims to.
    """
    out = subprocess.run(
        [
            "ffmpeg", "-nostdin", "-v", "error", "-i", path,
            "-vf", f"fps={SAMPLES_PER_SECOND},scale=64:-1,signalstats,"
                   "metadata=print:file=-",
            "-an", "-f", "null", "-",
        ],
        capture_output=True, text=True, check=True,
    ).stdout

    series: list[tuple[float, float]] = []
    timestamp: float | None = None
    for line in out.splitlines():
        found = re.search(r"pts_time:([0-9.]+)", line)
        if found:
            timestamp = float(found.group(1))
            continue
        found = re.search(r"lavfi\.signalstats\.YAVG=([0-9.]+)", line)
        if found and timestamp is not None:
            series.append((timestamp, float(found.group(1))))
    return series


def longest_dark_run(series: list[tuple[float, float]]) -> tuple[float, float]:
    best = (0.0, 0.0)
    run_start: float | None = None
    previous = 0.0
    for timestamp, luma in series:
        if luma < DARK_MAX_LUMA:
            if run_start is None:
                run_start = timestamp
            previous = timestamp
        elif run_start is not None:
            if previous - run_start > best[1] - best[0]:
                best = (run_start, previous)
            run_start = None
    if run_start is not None and previous - run_start > best[1] - best[0]:
        best = (run_start, previous)
    return best


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: find_app_session.py <raw-recording.mp4>", file=sys.stderr)
        return 2

    series = luma_series(sys.argv[1])
    if not series:
        print("no frames measured", file=sys.stderr)
        return 1

    start, end = longest_dark_run(series)
    if end - start < MIN_SESSION_SECONDS:
        print(
            f"longest dark stretch is {end - start:.1f}s, too short to be the "
            f"app session — the app probably failed to launch",
            file=sys.stderr,
        )
        return 1

    print(f"{start:.3f} {end:.3f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
