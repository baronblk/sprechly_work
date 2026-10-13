# Raw output — Phase 6 live audio pipeline

Device: iPhone 17 Pro, iOS 27.0.1 · 2026-10-04
Unaltered test output. Do not overwrite — later runs get their own file.

## Formats of the live path

```
PIPELINE SHAREABLE writer-target-equals-analyzer-format=false
PIPELINE analyzer 16000Hz ch=1 fmt=3 interleaved=true
PIPELINE analyzer-candidate 16000Hz ch=1 fmt=3 interleaved=true equals-writer-target=false
PIPELINE analyzer-candidate 8000Hz ch=1 fmt=3 interleaved=true equals-writer-target=false
PIPELINE capture  48000Hz ch=1 fmt=1 interleaved=false
PIPELINE capture-equals-analyzer-format=false
PIPELINE capture-equals-writer-target=true
PIPELINE writer   48000Hz ch=1 fmt=1 interleaved=false
```

## Conversion cost (real tap parameters: 4096 frames @ 48 kHz)

```
COST noop-conversion callbacks=42187 total=0.2626s per-callback=6.2us cpu-share-of-realtime=0.0073%
COST speech-conversion callbacks=42187 total=0.3164s per-callback=7.5us cpu-share-of-realtime=0.0088%
COST aac-file-write callbacks=703 total=0.1040s per-callback=147.9us cpu-share-of-realtime=0.1733%
```

## File finalization after stop() — pre-existing, non-deterministic

Before the bounded wait (this phase's code):
```
SEQ same-engine-take1 UNREADABLE reported=1.9857291666666668 bytes=93974 error=Error Domain=com.apple.coreaudio.avfaudio Code=1685348671 
SEQ same-engine-take2 OK reported=1.9857291666666668 file=1.9857291666666668 bytes=95099
SEQ fresh-engine-take1 OK reported=1.9857291666666668 file=1.9857291666666668 bytes=93544
SEQ fresh-engine-take2 UNREADABLE reported=1.9857291666666668 bytes=93139 error=Error Domain=com.apple.coreaudio.avfaudio Code=1685348671 
SEQ isolated OK reported=1.9857291666666668 file=1.9857291666666668 bytes=94718
```

Same probe on a5cc2e2, the end of Phase 5, before any Phase 6 change:
```
(see report: 2 of 5 takes unreadable, different ones)
```

With the bounded wait:
```
SEQ same-engine-take1 readable-after=0.0s reported=1.9857291666666668 file=1.9857291666666668 bytes=94311
SEQ same-engine-take2 readable-after=0.1s reported=1.9857291666666668 file=1.9857291666666668 bytes=94175
SEQ fresh-engine-take1 readable-after=0.1s reported=1.9857291666666668 file=1.9857291666666668 bytes=93706
SEQ fresh-engine-take2 readable-after=0.0s reported=1.9857291666666668 file=1.9857291666666668 bytes=94961
SEQ isolated readable-after=0.1s reported=1.9857291666666668 file=1.9857291666666668 bytes=94278
```

## 5-minute recording, simplified code

```
LONGREC long readable after 0.000s
LONGREC requested=300.000s wall=300.202s reported=299.989s file=299.989s drift=0.000s bytes=4891018
LONGREC sink buffers=3000 frames=14400000 seconds=300.000 formats=1
LONGREC meters count=8999 maxGap=0.127s lastElapsed=299.989s
LONGREC cancel readable after 0.100s
LONGREC CANCEL reported=1.986s file=1.986s
```

## 30-minute recording, simplified code

```
LONGREC long readable after 0.000s
LONGREC requested=1800.000s wall=1800.210s reported=1799.993s file=1799.993s drift=0.000s bytes=29447126
LONGREC sink buffers=18000 frames=86400000 seconds=1800.000 formats=1
LONGREC meters count=53999 maxGap=0.148s lastElapsed=1799.993s
LONGREC cancel readable after 0.000s
LONGREC CANCEL reported=1.986s file=1.986s
```

## Frozen benchmarks after the simplification — identical to Phase 5

```
FORMAT-de MARKUP AUDIT \letter=2
FORMAT-de SUMMARY BEFORE wer=0.250 cer=0.067 terms=13/31 recall=0.419 fmt-acc=0.619 fmt-miss=8 rec-miss=10 fp=0
FORMAT-de SUMMARY AFTER-ALL wer=0.155 cer=0.042 terms=20/31 recall=0.645 fmt-acc=0.909 fmt-miss=2 rec-miss=9 fp=0
FORMAT-de DELTA AFTER-ALL wer=-0.095 cer=-0.025 terms=20-vs-13 fmt-acc=0.290 false-corrections=0
FORMAT-en MARKUP AUDIT none
FORMAT-en SUMMARY BEFORE wer=0.195 cer=0.065 terms=20/31 recall=0.645 fmt-acc=0.800 fmt-miss=5 rec-miss=6 fp=0
FORMAT-en SUMMARY AFTER-ALL wer=0.173 cer=0.064 terms=21/31 recall=0.677 fmt-acc=0.840 fmt-miss=4 rec-miss=6 fp=0
FORMAT-en DELTA AFTER-ALL wer=-0.022 cer=-0.001 terms=21-vs-20 fmt-acc=0.040 false-corrections=0
```
