---
name: superframes-cut
description: Cut, join, mix, conform and export video with FFmpeg — frame-exact trims, safe concatenation, loudness normalisation, voiceover ducking, speed changes, burned captions, colour-tagged delivery encodes, and the flags that avoid the classic desync and drift bugs.
---

**Usage beacon:** run `npx hyperframes events --skill=superframes-cut` once as this skill starts. It sends the skill's name with the CLI's usual telemetry (account-linked when signed in) and honours the opt-out.

# SuperFrames Cut — FFmpeg

FFmpeg is not a tool you use once; it is the stage where a correct film becomes a broken file. This skill is the flag set that does not break, wrapped in `scripts/superframes/cut.sh` so you do not retype it.

Stage reference with the reasoning behind every choice: `../superframes-edit/references/cut-export.md`.

## Before the first command

```bash
bash ../superframes-edit/scripts/superframes/doctor.sh
```

It reports the FFmpeg version and whether the build uses `-fps_mode` (5.1+) or `-vsync` (older), and whether `drawtext` and `subtitles` are compiled in. Those three facts decide which commands below are valid on this machine.

## Choose the cut before writing it

| Need | Command |
| --- | --- |
| Frame-exact cut a viewer will judge | `cut.sh trim IN OUT START DURATION` (re-encodes) |
| Rough assembly, lossless, instant | `cut.sh fast-trim IN OUT START [DURATION]` (stream copy, keyframe-aligned) |
| Join files that differ in any way | `cut.sh concat OUT FILE...` (concat filter, normalises) |
| Join byte-identical files | `ffmpeg -f concat -safe 0 -i list.txt -c copy out.mp4` |
| Loudness to a platform target | `cut.sh normalise IN OUT [-14] [-1]` (two-pass) |
| Voiceover over a music bed | `cut.sh mix OUT VOICE MUSIC [-18]` (sidechain ducking) |
| Extract audio for mixing or transcription | `cut.sh extract-audio IN OUT.wav` |
| Still frames and a contact sheet | `cut.sh frames IN OUTDIR 1` |
| Force constant frame rate and 48 kHz | `cut.sh conform IN OUT 30` |
| Speed ramp, video and audio together | `cut.sh speed IN OUT 1.5` |
| Burn a subtitle file | `cut.sh burn-subs IN OUT subs.srt` |
| Delivery encode | `cut.sh export IN OUT master\|web\|social\|vertical\|square` |
| What is this file | `cut.sh probe FILE` |

Every subcommand prints the exact `ffmpeg` invocation it runs, so the job is replayable by hand.

## The six failures, and their fixes

1. **Cut starts late or freezes on frame one.** Stream copy snapped to the previous keyframe. Re-encode (`trim`), do not compensate with an earlier start time.
2. **Audio drifts over a long timeline.** Mixed sample rates (44.1k joined to 48k) or a variable-frame-rate source. `conform` every source first; concat with the filter.
3. **Loudness is nowhere near the target after joining.** Each clip was normalised before concatenation. Assemble first, normalise once, at the end.
4. **The file got longer after an audio-only re-encode.** ACES padding. Pass `-shortest` plus an explicit `-t` equal to the original duration.
5. **A join shows a black flash or loses audio.** The concat demuxer dropped a stream that one segment lacked. Use the concat filter, which substitutes silence.
6. **Colour looks washed out.** Untagged full-range RGB presented as limited-range YUV. Tag every delivery encode: `-color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv`.

## Delivery targets

| Preset | Dimensions | Video | Audio | Use |
| --- | --- | --- | --- | --- |
| `master` | source | H.264 CRF 12, High 4.2 | AAC 320k | the file you keep and re-export from |
| `web` | source | H.264 CRF 19, High 4.1, 2 s GOP | AAC 192k | `<video>` on a site |
| `social` | 1920x1080 | H.264 CRF 21 | AAC 192k | YouTube, Vimeo, feed |
| `vertical` | 1080x1920 | H.264 CRF 21, cover-crop | AAC 192k | Reels, TikTok, Shorts |
| `square` | 1080x1080 | H.264 CRF 21, cover-crop | AAC 192k | feed grid |

All presets emit `+faststart` MP4, 48 kHz stereo, `bt709/tv` tags, and a constant frame rate. Loudness is *not* touched by an export preset: normalise before exporting, so every derivative inherits the same mix.

A cover-crop to 9:16 removes the sides of a 16:9 frame. If a subject sits near an edge it will be lost; build the vertical edition with its own layout instead, or reframe deliberately.

## Reading FFmpeg's output

| Line | Means |
| --- | --- |
| `Input #0 … Duration: 00:00:18.00, start: 0.000000` | the real duration; compare it to the spec |
| `Stream #0:0 … 30 fps, 1920x1080` | the real rate and size, not the filename's claim |
| `[libx264 @ …] kb/s: 4210` | the encoded bitrate; a CRF of 18 giving 400 Mbps means the content is noise |
| `frame= 540` at the end | frames written; should equal duration × fps |
| `Non-monotonous DTS` | timestamps were repaired; re-encode the source, it is now suspect |
| `deprecated pixel format used` | you omitted `-pix_fmt yuv420p`; browsers will refuse the file |

## Rules that are not preferences

- Never `-c copy` a cut a viewer will judge.
- Never normalise before concatenating.
- Never crop a master to a different aspect without looking at the result.
- Never export without an explicit `-pix_fmt yuv420p` for web playback.
- Never trust a filename for a codec, size or rate; `cut.sh probe` first.
- Always verify the output (`../superframes-edit/references/verify.md`); FFmpeg exit code 0 does not mean the file is right.

## Where to read next

| Need | Read |
| --- | --- |
| Why these flags, with the failure modes | `../superframes-edit/references/cut-export.md` |
| Verification of the exported file | `../superframes-edit/references/verify.md` |
| The full pipeline this stage belongs to | `../superframes-edit/SKILL.md` |
