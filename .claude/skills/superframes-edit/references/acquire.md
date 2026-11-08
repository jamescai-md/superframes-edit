# Stage 1 — Acquire references and footage

yt-dlp is the acquisition layer. In this skill it is never used to "get a clip" freehand: every download is reproducible from a logged command, and every file it produces lands in `assets/` with a provenance record.

## The rule

Nothing is downloaded without writing down: the URL, the extractor, the chosen format id, the uploader, the title, the duration, the licence class, and the local filename. `scripts/superframes/provenance.sh` writes that record for you.

```bash
bash scripts/superframes/provenance.sh add \
  --url "https://example.com/watch?v=ID" \
  --file assets/ref/clip.mp4 \
  --licence "standard-youtube" \
  --use "reference only, not redistributed"
```

## Triage before downloading

Never download a whole video to find out what it is.

```bash
yt-dlp --skip-download --print "%(id)s | %(duration_string)s | %(width)sx%(height)s | %(fps)s fps | %(uploader)s | %(title)s" "<URL>"
```

Choose the intent:

```bash
# A. Reference to copy the look and timing of. Small is fine; metadata matters.
yt-dlp -f "bv*[height<=1080]+ba/b[height<=1080]" --merge-output-format mp4 \
  --write-info-json --write-subs --sub-langs "en.*" --convert-subs srt \
  --force-keyframes-at-cuts -o "assets/ref/%(id)s.%(ext)s" "<URL>"

# B. Footage that will be cut into the edit. Highest quality, no subs, no thumbnails.
yt-dlp -f "bv*+ba/b" --merge-output-format mp4 --no-part \
  -o "assets/footage/%(title).80B [%(id)s].%(ext)s" "<URL>"

# C. Only a section — cheaper and cleaner than downloading then trimming.
yt-dlp -f "bv*[height<=1080]+ba/b" --download-sections "*00:01:12-00:01:48" \
  --force-keyframes-at-cuts --merge-output-format mp4 -o "assets/footage/%(id)s-cut.%(ext)s" "<URL>"

# D. Audio only, for a bed, a reference track or transcription.
yt-dlp -x --audio-format wav --audio-quality 0 -o "assets/audio/%(id)s.%(ext)s" "<URL>"

# E. Subtitles or a transcript only.
yt-dlp --skip-download --write-auto-subs --write-subs --sub-langs "en.*" \
  --convert-subs srt -o "assets/subs/%(id)s.%(ext)s" "<URL>"

# F. Stills for style analysis — a storyboard sheet from a reference.
yt-dlp -f "bv*" --download-sections "*00:00:00-00:00:10" -o "assets/ref/probe.%(ext)s" "<URL>"
ffmpeg -i assets/ref/probe.mp4 -vf "fps=1,scale=480:-1,tile=5x2" -frames:v 1 assets/ref/sheet.png
```

## Format selectors that do not lie

The single most common failure is a selector that quietly matched something else.

| Want | Selector | Why |
| --- | --- | --- |
| Best video plus best audio, merged | `bv*+ba/b` | `*` allows a format that already has audio when no separate audio exists |
| Cap the resolution | `bv*[height<=1080]+ba/b[height<=1080]` | the trailing `/b[...]` is the fallback when the pair is unavailable |
| Prefer H.264 for editing compatibility | `bv*[vcodec^=avc1]+ba/b` | AV1 and VP9 decode slowly in some NLEs and browsers |
| Prefer a specific container | `--merge-output-format mp4` | merge refuses when the streams are incompatible; the flag prevents `.mkv` surprises |
| Audio only | `-x --audio-format wav` | WAV avoids a second lossy encode before mixing |

Verify what you got rather than trusting the selector:

```bash
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,r_frame_rate,duration \
  -of default=nw=1 assets/footage/clip.mp4
```

## Cookies, geoblocks, and other walls

| Symptom | Cause | Fix |
| --- | --- | --- |
| "Sign in to confirm you're not a bot" | anonymous request flagged | `--cookies-from-browser firefox` (or `chrome`), retry |
| "This video is only available to members" | authenticated content | cookies from a signed-in browser profile; check the licence before use |
| "Unsupported URL" for a page that plays in a browser | extractor lag or a client mismatch | `yt-dlp -U`, then `--extractor-args "youtube:player_client=web,android"` |
| 403 mid-download | expiring URLs on long jobs | `--concurrent-fragments 4` plus retries; re-run for the missing range |
| Geo-restricted | region lock | `--proxy` with a permitted exit node, or pick another reference; do not fake a locale for licensed content |
| Private or age-gated | credentials | cookies; never ask the person to paste a password into the chat |

Newer yt-dlp builds add `--impersonate` for TLS-fingerprint walls: `yt-dlp --impersonate chrome "<URL>"` when a site blocks plain HTTP clients. It requires the optional `curl_cffi` dependency; if the flag errors, the dependency is missing and the wall is not TLS-based.

## Playlists and channels

```bash
yt-dlp --flat-playlist --print "%(playlist_index)s %(id)s %(title)s" "<PLAYLIST>"
yt-dlp --playlist-items 1-8 --max-downloads 8 \
  --download-archive assets/.archive.txt -o "assets/footage/%(playlist_index)02d-%(id)s.%(ext)s" "<PLAYLIST>"
```

`--download-archive` makes re-runs idempotent. Use it whenever a job may be resumed; a half-finished playlist otherwise redownloads from zero.

## Politeness and cost

- `--sleep-requests 1` between metadata requests when pulling many references.
- `--limit-rate 8M` when the person is on a metered link.
- Prefer `--download-sections` over downloading an hour to use forty seconds.
- Delete intermediates you will not deliver, and say what you deleted.

## Copyright guardrail

Downloading a reference is not a licence to publish it. Classify every asset at intake:

| Class | Meaning | Allowed use in the deliverable |
| --- | --- | --- |
| `own` | the person's own recording or asset | anything |
| `licensed` | a licence was supplied or purchased | per the licence terms; record the term |
| `cc-by` | Creative Commons attribution | requires on-screen or in-notes credit; record the attribution string |
| `cc0` / `public-domain` | no restrictions | anything |
| `reference-only` | studied for style, not reshipped | analysis, never pixels in the master |
| `unknown` | no basis established | ask before it enters a master; default to `reference-only` |

`reference-only` footage that gets traced, matched or colour-copied is still reference-only: rebuild the look from your own assets, and say so in `DELIVERY.md`.

## Exit condition

- Files exist under `assets/` with the containers and dimensions you intended.
- Each has a provenance record with a licence class.
- Anything `reference-only` is in `assets/ref/`, never `assets/footage/`.
- The exact commands are in `ACQUISITION.md` so the job can be replayed.
