---
name: superframes-acquire
description: Get reference media in and measure it with yt-dlp and FFmpeg — download clips, sections, audio, subtitles and stills reproducibly, defeat bot and cookie walls, record provenance and licence class, then probe a reference for cuts, palette, motion and loudness so "make it like this" becomes numbers.
---

**Usage beacon:** run `npx hyperframes events --skill=superframes-acquire` once as this skill starts. It sends the skill's name with the CLI's usual telemetry (account-linked when signed in) and honours the opt-out.

# SuperFrames Acquire — yt-dlp, FFmpeg, provenance

Two jobs: get media in without breaking it, and turn a reference into measurements. Full reasoning in `../superframes-edit/references/acquire.md` and `../superframes-edit/references/analyze.md`.

## Before the first command

```bash
bash ../superframes-edit/scripts/superframes/doctor.sh
```

If `yt-dlp` is missing, everything except this skill still works; say so and continue. If it is missing and the job needs a reference, print the one install line and wait rather than guessing at footage.

## Identify before downloading

```bash
yt-dlp --skip-download --print "%(id)s | %(duration_string)s | %(width)sx%(height)s | %(fps)s fps | %(uploader)s | %(title)s" "<URL>"
```

Never pull a whole video to find out what it is. Then pick the intent:

| Want | Command |
| --- | --- |
| A reference to study | `yt-dlp -f "bv*[height<=1080]+ba/b[height<=1080]" --merge-output-format mp4 --write-info-json --write-subs --sub-langs "en.*" --convert-subs srt -o "assets/ref/%(id)s.%(ext)s" "<URL>"` |
| Footage to cut into the edit | `yt-dlp -f "bv*+ba/b" --merge-output-format mp4 -o "assets/footage/%(title).80B [%(id)s].%(ext)s" "<URL>"` |
| Only a section | `yt-dlp -f "bv*[height<=1080]+ba/b" --download-sections "*00:01:12-00:01:48" --force-keyframes-at-cuts --merge-output-format mp4 -o "assets/footage/%(id)s-cut.%(ext)s" "<URL>"` |
| Audio only | `yt-dlp -x --audio-format wav --audio-quality 0 -o "assets/audio/%(id)s.%(ext)s" "<URL>"` |
| Subtitles or a transcript | `yt-dlp --skip-download --write-auto-subs --write-subs --sub-langs "en.*" --convert-subs srt -o "assets/subs/%(id)s.%(ext)s" "<URL>"` |
| Still frames from a reference | download 10 s, then `bash scripts/superframes/cut.sh frames clip.mp4 stills 1` |
| A whole playlist, resumable | `yt-dlp --playlist-items 1-8 --download-max 8 --download-archive assets/.archive.txt -o "assets/footage/%(playlist_index)02d-%(id)s.%(ext)s" "<PLAYLIST>"` |

Reject a download that does not match the intent: `bash scripts/superframes/cut.sh probe FILE`. A 360p file where 1080p was requested means the selector matched a fallback, and the reference is now useless for measuring type.

## Walls

| Symptom | Fix |
| --- | --- |
| "Sign in to confirm you're not a bot" | `--cookies-from-browser firefox` (or `chrome`), retry |
| "Unsupported URL" for a page that plays | `yt-dlp -U`, then `--extractor-args "youtube:player_client=web,android"` |
| 403 mid-download | `--concurrent-fragments 4`, re-run for the missing range |
| TLS-fingerprint block | `--impersonate chrome` (needs `curl_cffi`; errors if absent) |
| Geo-restricted | `--proxy`, or choose another reference; do not fake a locale for licensed content |
| Members-only | cookies from a signed-in profile, and check the licence before use |

Never ask a person to paste a password. Cookies from their own browser, or nothing.

## Provenance is part of acquiring

Every downloaded file gets a row, or delivery is blocked:

```bash
bash scripts/superframes/provenance.sh init
bash scripts/superframes/provenance.sh add --file assets/ref/clip.mp4 \
  --url "<URL>" --licence reference-only --use "style study, not shipped"
bash scripts/superframes/provenance.sh check
```

Classes: `own`, `licensed`, `cc-by` (needs a credit string), `cc0`, `reference-only`, `unknown`. `unknown` fails the check, which is the point.

`reference-only` means the pixels never reach a master. Rebuild the look from your own assets and say so in `DELIVERY.md`.

## Measure the reference

```bash
bash scripts/superframes/analyze.sh REF.mp4 --out analysis/ --threshold 0.3
```

Writes `probe.txt`, `scenes.txt`, a shot-table skeleton, `audio.txt` (loudness and silence map), `palette.png`, `sheet.png`, per-second frames, and a fillable `ANALYSIS.md`.

Then read them, and fill in the judgement the script cannot make:

| Question | Where the answer goes |
| --- | --- |
| Where are the cuts, and is the pacing even? | shot table |
| What motion vocabulary, in numbers? | motion table |
| Six hex roles and the grade name | palette section |
| Type scale, margins, safe zones | type section |
| Does the cut land on the beat? | audio section |
| What to copy, what to change | the last section, always filled |

## Rules that are not preferences

- Nothing is downloaded without a provenance row and a licence class.
- Nothing is downloaded at full length to inspect it.
- Never re-download a file you already have; use `--download-archive`.
- Never ship `reference-only` pixels, and never claim a rebuild is a copy.
- A reference's framerate and dimensions are measured, not assumed from the title.
- Copy the system, not the film. State the difference in `ANALYSIS.md` and `DELIVERY.md`.

## Where to read next

| Need | Read |
| --- | --- |
| Acquisition reasoning, format selectors, walls | `../superframes-edit/references/acquire.md` |
| Analysis, shot tables, palettes, beat grids | `../superframes-edit/references/analyze.md` |
| Building the thing you measured | `../superframes-edit/references/build.md` |
| Verification against the reference | `../superframes-edit/references/verify.md` |
