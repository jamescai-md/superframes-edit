# Stage 6 — Verify

A render that "succeeded" is not a render that is correct. This stage is the difference between an agent that reports and an agent that knows.

## The gate

```bash
bash scripts/superframes/verify.sh out/master.mp4 \
  --expect-duration 18.0 --expect-size 1920x1080 --expect-fps 30 \
  --audio --black --freeze --frames out/verify --json
```

Each check returns `PASS`, `WARN` or `FAIL`. `FAIL` blocks delivery. `WARN` is allowed, but must be written into `DELIVERY.md` with a reason.

| Check | What it proves | FAIL means |
| --- | --- | --- |
| file | the file is non-empty | the render wrote nothing |
| video-stream | codec, dimensions, fps, pixel format | wrong or missing video |
| duration | matches the spec within tolerance | content was cut or padded |
| dimensions | matches the spec exactly | wrong export preset |
| fps | matches within 0.01 | a re-encode changed the rate |
| frame-count | frames ÷ fps ≈ duration | the render ended early or overran |
| colour-tags | primaries/range are declared | players will guess and shift colour |
| loudness | within 1–3 LU of target | audio was never normalised |
| true-peak | under the ceiling | inter-sample clipping |
| sample-rate | 48 kHz | a mismatched rate will drift on concat |
| av-sync-start | streams begin together | an offset to chase down |
| black-runs | no unintended black | a dropped segment, or an intended card |
| freeze-runs | no stuck frames | a decode or capture failure |
| ssim-vs-ref | ≥0.95 against a reference | this is not the film you meant to make |

## Looking at frames is not optional

Numbers cannot see a slab of unstyled text or the wrong font. Extract and open frames.

```bash
bash scripts/superframes/cut.sh frames out/master.mp4 out/verify 1   # stills + contact sheet
```

Then actually open `out/verify/sheet.png` and at least one full-size frame per distinct scene. What to look for:

- **A font fell back.** Letterforms are the giveaway; compare against the intended face.
- **Safe areas.** Nothing important within 5% of the edge; captions above the platform's UI zone.
- **Legibility.** Text over footage needs contrast; a 4.5:1 ratio on the darkest and lightest part of the background.
- **Stray elements.** A debug label, a placeholder box, a duplicated layer.
- **The first and last frame.** Black, or a mid-motion frame where a settled state was intended.
- **Every transition.** Snapshot the frames either side of each cut; that is where artifacts live.

In HyperFrames, `npx hyperframes snapshot --range <start>,<end>` renders a range and the check report lists layout and contrast findings. In Remotion, `npx remotion still <id> out.png --frame=<n>` gives an exact frame.

## Comparing to a reference

When the job was "make it look like this", prove it with pixels:

```bash
bash scripts/superframes/verify.sh out/master.mp4 --against assets/ref/reference.mp4 --json
```

SSIM bands: `≥0.95` visually equivalent; `0.85–0.95` close, with identifiable divergent shots; `<0.85` a different film. PSNR above roughly 35 dB is close, above 40 dB is very close — but PSNR flatters flat frames, so read SSIM first.

For a shot-by-shot comparison, take a frame from the same timecode in both and look at them side by side. Global metrics hide a single badly wrong shot.

## A/V sync, concretely

`verify.sh` reports when the streams *start* together. It cannot tell you whether a lip flap matches a syllable mid-film. For that:

1. Find a moment with a hard visual event and a hard sound (a clap, a door, a button).
2. Extract ±200 ms of both around it:
   ```bash
   ffmpeg -ss 4.80 -i out/master.mp4 -t 0.4 -vf "fps=30" -an out/verify/sync-frames/f-%03d.png
   ffmpeg -ss 4.80 -i out/master.mp4 -t 0.4 -vn out/verify/sync.wav
   ```
3. Open the waveform and the frames; the event should sit within one frame (33 ms at 30 fps).

A constant offset of a few frames across the whole film means the audio was offset at assembly. Fix it once with `-itsoffset` and re-mux; do not chase it per-clip:

```bash
ffmpeg -i in.mp4 -itsoffset 0.066 -i in.mp4 -map 0:v -map 1:a -c copy out.mp4
```

## Cheap checks that catch expensive problems

| Check | Command | Catches |
| --- | --- | --- |
| Duration | `ffprobe -show_entries format=duration` | truncated renders |
| Stream summary | `ffprobe -show_streams` | missing audio, wrong codec |
| Frame count | `ffprobe -count_packets` | early end, padded tail |
| Black segments | `blackdetect` | dropped scenes |
| Frozen segments | `freezedetect` | capture stall |
| Silence map | `silencedetect` | a missing voice track, dead air |
| Loudness | `loudnorm` two-pass | unnormalised delivery |
| Palette | `palettegen` | a colour cast you stopped seeing |
| Bitrate | `ffprobe -show_entries format=bit_rate` | a CRF that produced a 400 Mbps master |

## What to write down

`VERIFICATION.md`, next to the project:

```markdown
# Verification — out/master.mp4

| Check | Result | Value |
| --- | --- | --- |
| duration | PASS | 18.000 s (spec 18.0 ± 0.15) |
| dimensions | PASS | 1920x1080 |
| fps | PASS | 30.000 |
| loudness | PASS | -14.2 LUFS (target -14) |
| true peak | PASS | -1.6 dBTP (ceiling -1.0) |
| colour tags | PASS | bt709/tv |
| frames reviewed | PASS | sheet.png + 4 scene frames |
| ssim vs reference | WARN | 0.91 — the end card differs on purpose |

Skipped: nothing.
Assumption: the reference's 24 fps was matched at 30 fps because the spec says 30.
```

If a check could not run — no ffmpeg, no reference file, no browser — say exactly which one and why. A skipped check is a disclosure, never a pass.

## Exit condition

- `verify.sh` produced no `FAIL`.
- Frames were opened and described.
- Loudness and peaks are measured values, not estimates.
- `VERIFICATION.md` exists, including anything skipped.
