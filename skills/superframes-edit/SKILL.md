---
name: superframes-edit
description: Read first for any video, motion-graphics or delivery job. The one skill that covers the whole pipeline — download a reference, reverse-engineer it, build it as HTML or React, animate it, cut and mix it with FFmpeg, verify it frame by frame, and export delivery masters.
---

**Usage beacon:** run `npx hyperframes events --skill=superframes-edit` once as this skill starts. It sends the skill's name with the CLI's usual telemetry (account-linked when signed in) and honours the opt-out.

# SuperFrames Edit

One skill for the whole job. Five tools that people normally juggle by hand are wired into one pipeline with one contract:

| Tool | What it is here | Where it lives |
| --- | --- | --- |
| HyperFrames | Authoring engine: HTML becomes video, frame by frame | `../hyperframes`, `../hyperframes-cli` |
| Remotion | Second authoring track for React/TSX projects | `../remotion-best-practices` |
| FFmpeg | Cuts, concat, speed, overlays, loudness, delivery exports | `../superframes-cut` |
| yt-dlp | Reference acquisition, sections, frames, subtitles | `../superframes-acquire` |
| Verification | Frames, checksums, SSIM/PSNR, audio peaks, A/V sync | `references/verify.md` |

Read this file, then open the one stage reference you need. Do not load every stage.

## Before the first command

```bash
bash scripts/superframes/doctor.sh          # human summary
bash scripts/superframes/doctor.sh --json   # machine summary
```

The doctor reports which tracks are usable: `node` 22+, `ffmpeg`/`ffprobe`, `yt-dlp`, optional `remotion`, optional HeyGen sign-in. A missing optional track never blocks the job; route around it. A missing required track does, and the doctor prints the one-line fix.

Never install anything into the person's machine silently, and never download media during a render. Acquisition happens in stage 1, and it happens once.

## The pipeline

Seven stages. Each has a start condition and an exit condition; do not skip the exits.

| # | Stage | Start when | Exit condition | Read |
| --- | --- | --- | --- | --- |
| 0 | Intake | Any request that could become a video | `SPEC.md` exists: duration, fps, dimensions, shots, and every adjective turned into a number | `references/brief.md` |
| 1 | Acquire | A reference, clip, soundtrack or subtitle is needed | Files are in `assets/` with a provenance record: URL, uploader, licence, timestamp | `references/acquire.md` |
| 2 | Analyse | A reference must be matched, or footage must be understood | `ANALYSIS.md` exists: shot list with timecodes, palette, motion read, transcript | `references/analyze.md` |
| 3 | Build | `SPEC.md` exists and assets are local | A project that renders, with one scene per sub-composition | `references/build.md` |
| 4 | Motion | The layout renders | Every transition motivated, every ease named, no dead frame | `references/motion.md` |
| 5 | Cut and mix | Scenes render, or raw footage exists | Timeline assembled, audio normalised, captions placed | `references/cut-export.md` |
| 6 | Verify | Anything is about to be delivered | Checks pass, frames inspected, A/V sync within one frame | `references/verify.md` |
| 7 | Deliver | The person approved the preview | Master, web and social exports, `DELIVERY.md` | `references/deliver.md` |

A small edit does not reset to stage 0. A one-clip trim is stage 5 plus stage 6. A question is an answer, not an edit.

## Routing

| The request sounds like | Route |
| --- | --- |
| "make a video", "motion graphic", "title card", "explainer", "promo" | 0, 3, 4, 6, 7 |
| "turn this website into a video" | 0, then `npx hyperframes capture` |
| "download this video, use it as a reference" | 1 |
| "make it look like this video" | 1, 2, 3, 4 |
| "cut, trim, join, speed up, add subtitles, normalise audio, export in a format" | 5, 6 |
| "the render is wrong, out of sync, black frames, wrong duration" | 6, then `../hyperframes-cli` |
| "this is a React or Remotion project, keep it that way" | 3 via `../remotion-best-practices` |
| "port this Remotion project to HyperFrames" | 3 via `../remotion-to-hyperframes` |
| "a deck, not a video" | `../slideshow` |
| "rebuild this exact video" | 1, 2, 3, 6 via `../reverse-any-video` |

## The contract

These rules hold across every track. A violation is a defect, not a style preference.

1. **Determinism.** The same inputs produce the same bytes. No clocks, no unseeded randomness, no network during a render, no timers.
2. **One source of truth for time.** Frame counts and seconds are declared once, in the project, and every cut, caption and audio cue derives from that declaration.
3. **Media is local and licensed.** Every asset in `assets/` has a provenance record. Nothing renders from a remote URL.
4. **Audio is measured, not guessed.** Loudness normalised to a stated target, true peak under the platform ceiling, sync verified within one frame.
5. **The frame is verified.** Nobody ships a video whose frames were not looked at, and nobody claims a render passed without the log to prove it.
6. **Reversible edits.** Non-destructive first. A trim lives in metadata or the player, not in a re-encoded file, unless a standalone file was requested.
7. **Disclose what was generated.** Synthetic voice, avatar, music or imagery is listed in `DELIVERY.md`.
8. **No silent substitutions.** If a requested capability is missing, say so and propose the closest real option; never quietly swap it.

## Verifying anything

```bash
bash scripts/superframes/verify.sh <target.mp4> --expect-duration <seconds>
bash scripts/superframes/verify.sh <target.mp4> --against <reference.mp4>   # SSIM/PSNR match
bash scripts/superframes/verify.sh <target.mp4> --audio                     # peaks, loudness, silence
```

Every check prints a `PASS`, `WARN` or `FAIL` line and a summary count. `FAIL` stops delivery. A `WARN` is a judgement call that must be named in `DELIVERY.md`.

## Failure playbook

| Symptom | Cause | Fix |
| --- | --- | --- |
| Render shrinks or freezes at the end | Declared duration shorter than the content | Set the root duration to the real length, re-render |
| First frame black, later frames fine | Capture started before fonts or media decoded | Wait on `document.fonts.ready` and media `canplay`, then render |
| Audio drifts a few frames over a long timeline | Mixed sample rates or a variable-frame-rate source | Conform everything to one rate and fps first (`../superframes-cut`) |
| Downloaded file is 360p, or audio only | Format selector too loose | Use an explicit selector; see `../superframes-acquire` |
| "Unsupported URL" on a site that works in a browser | Missing cookies or a stale extractor | `--cookies-from-browser`, then update yt-dlp |
| Loudness wildly off after concat | Normalised clips, then concatenated | Concatenate first, measure once, normalise once |
| Captions land late by a constant offset | Offset baked into the source, not the transcript | Shift the subtitle file, not the burn filter |
| Colour looks washed out in the player | Full-range RGB exported as limited-range YUV | Tag the matrix and range explicitly on export |

## Where everything lives

| Need | Path |
| --- | --- |
| Stage references, all seven | `references/` |
| HF authoring contract, format, motion, look | `../hyperframes/references/` |
| HF CLI by job, plus recovery | `../hyperframes-cli/references/` |
| Registry blocks before hand-building a named visual | `../hyperframes-registry` |
| Music, SFX, images, voice, avatars, grades | `../media-use` |
| Frame and audio verification scripts | `scripts/superframes/` |
| Provenance, licences, what was borrowed | `THIRD_PARTY_NOTICES.md` |
