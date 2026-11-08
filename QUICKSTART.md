# Quickstart

Five minutes from install to a verified MP4.

## 1. Install

Choose one. Each installs the same thirteen skills.

```bash
# Claude Code
claude plugin marketplace add jamescai-md/superframes-edit
claude plugin install superframes-edit@superframes-edit

# Codex, OpenCode, or any agent with the skills CLI
npx skills add jamescai-md/superframes-edit

# Gemini CLI
gemini extensions install https://github.com/jamescai-md/superframes-edit
```

No package manager route? Copy `skills/` into your project and point the agent at
`skills/superframes-edit/SKILL.md`.

## 2. Check the machine

```bash
bash skills/superframes-edit/scripts/superframes/doctor.sh
```

Required: Node 22+, `ffmpeg`, `ffprobe`. Optional: `yt-dlp` (references), Chrome (render and
preview), a HeyGen sign-in (catalog music, assets, voice).

```text
  ok    node           22.20.0
  ok    ffmpeg         7.0.2 at /usr/bin/ffmpeg (fps_mode available)
  ok    yt-dlp         2026.10.26
  GAP   chrome         binary present but cannot launch (missing shared libraries)
  GAP   render space   0.9 GB free at /tmp — renders need 5 GB+, set TMPDIR
```

A `GAP` on a required track stops a job. A `GAP` on an optional one routes around it: without
Chrome you can still cut, mix, export and verify; you cannot render a HyperFrames film.

## 3. Ask for the film

Give the agent a request with numbers in it, or let it ask:

```text
Using /superframes-edit, make a 15-second 16:9 launch film for the export feature.
Music, captions, no voiceover. Deliver a web MP4 and a vertical cut.
```

What happens, in order:

| Stage | Output you can look at |
| --- | --- |
| Intake | `SPEC.md` — duration, fps, size, beats, and every adjective as a number |
| Acquire | `assets/` + `PROVENANCE.tsv` — anything downloaded, with a licence class |
| Analyse | `ANALYSIS.md` — only if a reference was involved |
| Build | a project that renders, one scene per file |
| Motion | transitions with a cause, curves and durations |
| Cut and mix | assembled timeline, loudness at target, colour tagged |
| Verify | `VERIFICATION.md` and a contact sheet |
| Deliver | `out/master`, `out/web`, `out/social`, `DELIVERY.md`, checksums |

## 4. Verify it yourself

The agent's claim is not the proof. One command is:

```bash
bash skills/superframes-edit/scripts/superframes/verify.sh out/web/film.mp4 \
  --expect-duration 15 --expect-size 1920x1080 --expect-fps 30 --audio --frames out/verify
```

```text
PASS  file                   12.41 MB mov,mp4
PASS  video-stream           h264 1920x1080 30.000 fps yuv420p
PASS  duration               15.000s (expected 15s)
PASS  frame-count            450 frames ≈ 450 expected
PASS  loudness               -14.10 LUFS (target -14)
PASS  true-peak              -1.40 dBTP (ceiling -1.0)
```

`FAIL` means do not deliver. `WARN` means deliverable with the reason written down. Then open
`out/verify/sheet.png` and look at the film — numbers cannot see a wrong font.

## 5. The most common things you will actually need

```bash
S=skills/superframes-cut/scripts/superframes/cut.sh

bash $S probe in.mp4                                  # what is this file, really
bash $S trim in.mp4 out.mp4 12.4 3.2                  # frame-exact cut
bash $S concat out.mp4 a.mp4 b.mp4 c.mp4              # join anything, safely
bash $S normalise in.mp4 out.mp4 -14 -1               # two-pass loudness
bash $S mix out.m4a voice.wav music.wav -18           # duck the bed under speech
bash $S frames in.mp4 out/stills 1                    # stills + contact sheet
bash $S export in.mp4 out.mp4 web                     # delivery encode, tagged
```

References:

```bash
A=skills/superframes-acquire/scripts/superframes

bash $A/analyze.sh reference.mp4 --out analysis/      # cuts, palette, loudness, shot table
bash $A/provenance.sh init                            # start the licence ledger
bash $A/provenance.sh check                           # block delivery on unknown licences
```

## 6. When something goes wrong

| Symptom | Read |
| --- | --- |
| The render is the wrong length, or freezes at the end | `skills/superframes-edit/references/build.md` |
| Audio drifts, or is far too quiet | `skills/superframes-cut/references/ffmpeg-notes.md` |
| A download is the wrong resolution, or blocked | `skills/superframes-acquire/references/ytdlp-notes.md` |
| The check fails but the frames look fine | `skills/superframes-edit/references/verify.md` |
| "Make it look like this video" | `skills/superframes-edit/references/analyze.md` |

The full failure playbook is the last section of `skills/superframes-edit/SKILL.md`.
