# yt-dlp field notes

The parts of yt-dlp that decide whether a reference is usable, and the syntax that is easy to get
wrong. Upstream `--help` is authoritative for the installed version; `yt-dlp --version` tells you
which one that is.

## Shape of the command

```
yt-dlp [OPTIONS] URL...
```

Options before the URL apply to the job; `--` separates when a URL could be read as an option.
`-o` templates decide the filename and, through directories in the template, the layout.

## Output templates

| Field | Meaning |
| --- | --- |
| `%(id)s` | the site's id; stable, best for dedupe |
| `%(title)s` | human title; needs sanitising for a filesystem |
| `%(ext)s` | final extension after merging |
| `%(duration)s` / `%(duration_string)s` | seconds / `H:MM:SS` |
| `%(uploader)s` / `%(channel)s` | who published it |
| `%(playlist_index)02d` | zero-padded index in a playlist |
| `%(upload_date)s` | `YYYYMMDD` |
| `%(format_id)s` | which format was chosen |
| `%(height)s` / `%(fps)s` | spatial and temporal size |

Cap long titles rather than letting the filesystem do it: `%(title).80B` truncates to 80 bytes.
Use `-o "assets/ref/%(id)s.%(ext)s"` for references (stable, dedupeable) and
`-o "assets/footage/%(title).80B [%(id)s].%(ext)s"` for footage a person will browse.

## Format selection

| Selector | Meaning |
| --- | --- |
| `bv*+ba/b` | best video plus best audio, falling back to a single file |
| `b` | best pre-merged single file |
| `bv*[height<=1080]+ba/b[height<=1080]` | cap resolution, with a fallback |
| `bv*[vcodec^=avc1]+ba/b` | prefer H.264 for editing compatibility |
| `ba/b` | best audio |
| `-f 137+140` | explicit ids from `-F` |
| `--format-sort res:1080,fps` | order preferences explicitly |

The `*` in `bv*` allows a format that already contains audio, which is what makes a site with no
separate audio track work. Without it the selector fails and yt-dlp falls back to something
unexpected.

Always verify what arrived:

```bash
ffprobe -v error -select_streams v:0 \
  -show_entries stream=codec_name,width,height,r_frame_rate -of default=nw=1 FILE
```

## The option groups that matter here

| Job | Options |
| --- | --- |
| Inspect without downloading | `--skip-download --print "%(id)s %(duration_string)s %(width)sx%(height)s %(title)s"` |
| Metadata sidecar | `--write-info-json` |
| Subtitles | `--write-subs --write-auto-subs --sub-langs "en.*" --convert-subs srt` |
| Embed subtitles | `--embed-subs` (mp4/mkv only) |
| Only a section | `--download-sections "*START-END"` (needs ffmpeg); `*from-url` uses the URL's own start/end |
| Keyframes at cut edges | `--force-keyframes-at-cuts` |
| Audio only | `-x --audio-format wav --audio-quality 0` |
| Remux without re-encoding | `--remux-video mp4` |
| Re-encode | `--recode-video mp4` (lossy; prefer remux) |
| Merge container | `--merge-output-format mp4` |
| Playlists | `--playlist-items 1-8`, `--max-downloads`, `--download-archive FILE` |
| Filters | `--match-filters`, `--dateafter`, `--min-filesize`, `--max-filesize` |
| Resume/no partials | `--part` (default) vs `--no-part` |
| Politeness | `--sleep-requests 1`, `--limit-rate 8M`, `--concurrent-fragments 4` |
| Live | `--live-from-start`, `--wait-for-video MIN-MAX` |
| Container for HLS | `--hls-use-mpegts` (default for live) |
| Update | `-U` / `--update-to CHANNEL@TAG` |

`--download-archive` records completed ids so a resumed run does not redownload. Use it for any
job that may be interrupted or re-run — the alternative is silently paying for the same bytes twice.

## Access walls, and the honest fix

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| "Sign in to confirm you're not a bot" | anonymous request flagged | `--cookies-from-browser firefox` (or `chrome`, `edge`, `brave`, `safari`) |
| "Unsupported URL" for a page that plays | extractor lag, or a client mismatch | `-U`; then `--extractor-args "youtube:player_client=web,android"` |
| 403 part-way | expiring media URLs on a long job | `--concurrent-fragments 4`, retry the missing range |
| TLS-fingerprint block | client heuristics | `--impersonate chrome` (requires `curl_cffi`; errors loudly if absent) |
| Geo-restricted | region lock | `--proxy` where permitted, or choose another reference |
| Members-only / private | authentication | cookies from a signed-in profile; check the licence first |
| Rate limited | too many requests | `--sleep-requests 1`, `--limit-rate` |

Cookies come from the person's own browser profile. Never ask anyone to paste a password or a
session token into a chat, and never commit a cookie file to a repo.

## Playlists and channels

```bash
yt-dlp --flat-playlist --print "%(playlist_index)s %(id)s %(title)s" URL   # inspect
yt-dlp --playlist-items 1-8 --download-archive assets/.archive.txt \
  -o "assets/footage/%(playlist_index)02d-%(id)s.%(ext)s" URL
```

`--flat-playlist` avoids resolving every entry — fast, and enough to choose what to download.
`--lazy-playlist` starts downloading as entries arrive; useful for long feeds, but disable it when
you need the whole list before filtering.

## What yt-dlp will not tell you

- Whether you are allowed to publish the file. That is the licence class, recorded in
  `PROVENANCE.tsv` — see `scripts/superframes/provenance.sh`.
- Whether the download matches your intent (resolution, codec, audio present). Probe it.
- Whether the timestamps are sane. A section download without `--force-keyframes-at-cuts` can start
  a few frames early or late.

## Exit codes

`0` on success, `1` when any download failed, `2` on a usage error. A partial playlist returns
non-zero; check which ids are missing rather than rerunning everything.
