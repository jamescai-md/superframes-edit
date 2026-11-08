# Stage 7 — Deliver

Delivery is a handoff, not a file drop. The next person — often a future you with no memory of this job — must be able to rebuild, defend and re-export what you made.

## The delivery set

```
out/
  master/            archival + highest quality
    master.mp4       H.264 CRF 12-16, 320k audio, +faststart
    master.mov       ProRes 422 HQ when the destination needs it
  web/               1920x1080 H.264 CRF 19, AAC 192k, +faststart
  social/
    vertical.mp4     1080x1920
    square.mp4       1080x1080
  captions/
    captions.srt     sidecar, same timing as the film
  stills/
    poster.png       frame 0 or a chosen hero frame
    sheet.png        contact sheet of the whole film
  DELIVERY.md
  VERIFICATION.md
```

Name files predictably: `<project>-<aspect>-<version>.<ext>`, e.g. `launch-16x9-v3.mp4`. No `final-final-2`. The version number goes up; nothing else does.

## `DELIVERY.md`

The one file a person reads when they open the folder.

```markdown
# Delivery — Launch film

## What this is
An 18-second launch film for the export feature. 16:9 master plus 9:16 and 1:1 cuts.

## Files
| File | Aspect | Duration | Size | Use |
| --- | --- | --- | --- | --- |
| out/master/master.mp4 | 16:9 | 18.00 s | 41 MB | archival + editing source |
| out/web/launch-16x9-v3.mp4 | 16:9 | 18.00 s | 12 MB | the website hero |
| out/social/vertical.mp4 | 9:16 | 18.00 s | 10 MB | Reels, TikTok |

## How it was made
- Authoring: HyperFrames, `index.html` + 4 scenes in `compositions/`
- Cuts and mix: FFmpeg (`scripts/superframes/cut.sh`), logged commands in `ACQUISITION.md`
- Reference: studied for pacing and palette, not for pixels (see `ANALYSIS.md`)

## Spec
1920x1080, 30 fps CFR, H.264 High, yuv420p, bt709/tv, -14 LUFS, -1 dBTP.

## Provenance
| Asset | Licence | Credit required |
| --- | --- | --- |
| assets/footage/hero.mp4 | own | no |
| assets/audio/bed.mp3 | licensed (Artlist, invoice 1234) | no |
| assets/img/map.png | cc-by | "Map: Someone, CC BY 4.0" — shown in the end card |

Generated content: voiceover synthesised with Voice Turbo (not a human recording).

## Verification
See `VERIFICATION.md`. All checks pass except: SSIM 0.91 against the reference,
because the end card intentionally differs.

## Warnings carried
- Colour tags were absent on the source; tagged bt709/tv manually on export.
- The 9:16 cut centre-crops the master; the product sits inside the safe 60% at all times.

## How to rebuild
```bash
npx hyperframes check --json && npx hyperframes render --quality delivery -o out/master/master.mp4
bash scripts/superframes/cut.sh export out/master/master.mp4 out/web/launch-16x9-v3.mp4 web
bash scripts/superframes/verify.sh out/web/launch-16x9-v3.mp4 --expect-duration 18 --audio
```

## Known limits
- No 4K master; the source footage is 1080p.
- Music is licensed for web and social, not broadcast.
```

## Disclosure rules

List anything a viewer would be surprised to learn:

- Synthetic voice, avatar, generated imagery, generated music.
- Stock or third-party footage, with its licence class.
- A font substitution for a licensed face.
- A reference that was studied but not shipped.
- Anything `reference-only` that informed the work.

A deliverable that hides its provenance is a liability, not a design choice.

## Integrity

```bash
sha256sum out/*/*.mp4 > out/SHA256SUMS
```

Include it when files travel by hand or through a review tool. It settles "is this the file I approved" in one command.

## The final message

When the files are ready, report:

1. **What was delivered** — file names, durations, aspects.
2. **What was verified** — the check summary, in one line.
3. **What was assumed or skipped** — with reasons.
4. **What is still open** — anything waiting on the person.

Keep it short. The detail is in `DELIVERY.md`, and saying so is enough.

## Exit condition

- Every file in the delivery set exists, plays, and passed `verify.sh`.
- `DELIVERY.md` and `VERIFICATION.md` are complete, with warnings carried over.
- Provenance passes: `bash scripts/superframes/provenance.sh check`.
- Checksums written.
- The person knows where the files are and what remains theirs to decide.
