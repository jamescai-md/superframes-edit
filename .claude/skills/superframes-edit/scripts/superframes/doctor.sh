#!/usr/bin/env bash
# doctor.sh — what this machine can actually do, before a job starts.
#
#   doctor.sh           human summary with a one-line fix per gap
#   doctor.sh --json    machine summary for an agent to route on
#   doctor.sh --fix     print the install commands (never runs them)
#
# Required: node 22+, ffmpeg, ffprobe.
# Optional: yt-dlp, bun, Chrome, HeyGen sign-in, TMPDIR with room to render.
#
# Exit codes: 0 every required track is usable, 1 a required track is missing.

set -uo pipefail
JSON=0; FIX=0
for a in "$@"; do
  case "$a" in
    --json) JSON=1 ;;
    --fix) FIX=1 ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }
REQUIRED_MISSING=0

# newest <cmd> ...  → first candidate that resolves
first_of() { for c in "$@"; do have "$c" && { printf '%s' "$c"; return 0; }; done; return 1; }

NODE_OK=0; NODE_VER="absent"
if have node; then
  NODE_VER=$(node -v 2>/dev/null | sed 's/^v//')
  major=${NODE_VER%%.*}
  [[ "$major" -ge 22 ]] 2>/dev/null && NODE_OK=1
fi

FFMPEG_BIN=$(first_of ffmpeg || true)
FFPROBE_BIN=$(first_of ffprobe || true)
FFMPEG_VER="absent"; FFMPEG_BIG=0
if [[ -n "$FFMPEG_BIN" ]]; then
  FFMPEG_VER=$("$FFMPEG_BIN" -version 2>/dev/null | head -1 | awk '{print $3}')
  # Versions before 5.1 spell the filtergraph rate control `-vsync`; newer builds
  # prefer -fps_mode. Knowing which one this machine has prevents a failed render.
  FFMPEG_BIG=$(awk -v v="${FFMPEG_VER%%-*}" 'BEGIN{split(v,a,"."); print (a[1]>5 || (a[1]==5 && a[2]>=1)) ? 1 : 0}')
fi

YTDLP_VER="absent"; if have yt-dlp; then YTDLP_VER=$(yt-dlp --version 2>/dev/null); fi
BUN_VER="absent";   if have bun;    then BUN_VER=$(bun --version 2>/dev/null); fi
NPX_OK=0; have npx && NPX_OK=1

# Render temp space: HyperFrames and Chrome both fail on a small TMPDIR.
TMP="${TMPDIR:-/tmp}"
# -Pk reports 1K blocks; convert, so a sub-gigabyte tmpfs is not silently "0 GB".
FREE_KB=$(df -Pk "$TMP" 2>/dev/null | awk 'NR==2{print $4}')
[[ -n "${FREE_KB:-}" ]] || FREE_KB=0
FREE_GB=$(awk -v k="$FREE_KB" 'BEGIN{printf "%.1f", k/1048576}')
TMP_OK=$(awk -v k="$FREE_KB" 'BEGIN{print (k>=5242880) ? 1 : 0}')

CHROME="absent"
for c in "google-chrome" "chromium" "chromium-browser" "chrome-headless-shell"; do
  have "$c" && CHROME="$c" && break
done
if [[ "$CHROME" == "absent" && -d "${HOME}/.cache/hyperframes/chrome" ]]; then
  CHROME="hyperframes cache"
fi

HEYGEN="signed-out"
AUTH_FILE="${HOME}/.hyperframes/auth.json"
[[ -f "$AUTH_FILE" ]] && HEYGEN="signed-in"

# A cached Chrome binary that cannot start is the most confusing render failure there is:
# the CLI reports "Chrome cannot launch (missing system libraries)" only after a job begins.
# Probe it here instead, cheaply, so the gap is known before the first render.
chrome_probe() {
  local bin=""
  if [[ "$CHROME" == "hyperframes cache" ]]; then
    bin=$(find "${HOME}/.cache/hyperframes/chrome" -name "chrome-headless-shell" -o -name "chrome" 2>/dev/null | head -1)
  elif [[ "$CHROME" != "absent" ]]; then
    bin=$(command -v "$CHROME" 2>/dev/null)
  fi
  [[ -n "$bin" ]] || { printf 'absent'; return; }
  if timeout 10 "$bin" --version >/dev/null 2>&1; then printf 'launches'; else printf 'blocked'; fi
}
CHROME_STATE=$(chrome_probe)
[[ "$NODE_OK" -eq 1 ]] || REQUIRED_MISSING=1
[[ -n "$FFMPEG_BIN" && -n "$FFPROBE_BIN" ]] || REQUIRED_MISSING=1

if [[ "$JSON" -eq 1 ]]; then
  printf '{'
  printf '"node":{"version":"%s","ok":%s},' "$NODE_VER" "$([[ $NODE_OK -eq 1 ]] && echo true || echo false)"
  printf '"ffmpeg":{"path":"%s","version":"%s","fps_mode":%s},' "${FFMPEG_BIN:-}" "$FFMPEG_VER" "$([[ $FFMPEG_BIG -eq 1 ]] && echo true || echo false)"
  printf '"ffprobe":{"path":"%s"},' "${FFPROBE_BIN:-}"
  printf '"ytdlp":{"version":"%s"},' "$YTDLP_VER"
  printf '"bun":{"version":"%s"},' "$BUN_VER"
  printf '"npx":%s,' "$([[ $NPX_OK -eq 1 ]] && echo true || echo false)"
  printf '"chrome":{"found":"%s","state":"%s"},' "$CHROME" "$CHROME_STATE"
  printf '"heygen":"%s",' "$HEYGEN"
  printf '"tmp":{"path":"%s","free_gb":%s,"ok":%s},' "$TMP" "$FREE_GB" "$([[ $TMP_OK -eq 1 ]] && echo true || echo false)"
  printf '"tracks":{"build_html":%s,"build_react":%s,"render_preview":%s,"cut":%s,"acquire":%s},' \
    "$([[ $NODE_OK -eq 1 ]] && echo true || echo false)" \
    "$([[ $NODE_OK -eq 1 && $NPX_OK -eq 1 ]] && echo true || echo false)" \
    "$([[ "$CHROME_STATE" == "launches" ]] && echo true || echo false)" \
    "$([[ -n "$FFMPEG_BIN" ]] && echo true || echo false)" \
    "$([[ "$YTDLP_VER" != "absent" ]] && echo true || echo false)"
  printf '"ok":%s}\n' "$([[ $REQUIRED_MISSING -eq 0 ]] && echo true || echo false)"
  exit "$REQUIRED_MISSING"
fi

ok()   { printf '  ok    %-14s %s\n' "$1" "$2"; }
gap()  { printf '  GAP   %-14s %s\n' "$1" "$2"; }
info() { printf '  --    %-14s %s\n' "$1" "$2"; }

printf 'SuperFrames Edit — capability check\n\n'
if [[ "$NODE_OK" -eq 1 ]]; then ok node "$NODE_VER"
else gap node "${NODE_VER}${NODE_VER:+ }(need 22 or newer) — nvm install 22, or use a remotion track with node 18+"; fi

if [[ -n "$FFMPEG_BIN" ]]; then ok ffmpeg "$FFMPEG_VER at $FFMPEG_BIN ($([[ $FFMPEG_BIG -eq 1 ]] && echo 'fps_mode available' || echo 'pre-5.1: use -vsync cfr'))"
else gap ffmpeg "not found — brew install ffmpeg | apt install ffmpeg | winget install Gyan.FFmpeg"; fi

if [[ -n "$FFPROBE_BIN" ]]; then ok ffprobe "$FFPROBE_BIN"; else gap ffprobe "not found — ships with ffmpeg"; fi

if [[ "$YTDLP_VER" != "absent" ]]; then ok yt-dlp "$YTDLP_VER"; else gap yt-dlp "not found — pip install -U yt-dlp (stage 1 unavailable, everything else works)"; fi
if [[ "$BUN_VER" != "absent" ]]; then ok bun "$BUN_VER"; else info bun "not installed (optional; npm works)"; fi
if [[ "$NPX_OK" -eq 1 ]]; then ok npx "available"; else gap npx "not found — comes with node"; fi
case "$CHROME_STATE" in
  launches) ok chrome "$CHROME (launches)" ;;
  blocked)  gap chrome "binary present but cannot launch (missing shared libraries) — Debian/Ubuntu: sudo apt install libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 libatspi2.0-0 libgbm1 libasound2; elsewhere: npx hyperframes browser ensure" ;;
  *)        gap chrome "no browser found — npx hyperframes browser ensure" ;;
esac

if [[ "$TMP_OK" -eq 1 ]]; then ok "render space" "${FREE_GB} GB free at $TMP"; else gap "render space" "${FREE_GB} GB free at $TMP — renders need 5 GB+; export TMPDIR=/a/bigger/disk"; fi
if [[ "$HEYGEN" == "signed-in" ]]; then ok heygen "signed in (catalog music, assets, voice)"; else info heygen "signed out (optional; free local tools still work)"; fi

printf '\nTracks\n'
[[ "$NODE_OK" -eq 1 ]] && printf '  usable   build (HyperFrames HTML)\n' || printf '  blocked  build (HyperFrames HTML) — needs node 22+\n'
[[ "$NODE_OK" -eq 1 && "$NPX_OK" -eq 1 ]] && printf '  usable   build (Remotion React)\n' || printf '  blocked  build (Remotion React)\n'
[[ -n "$FFMPEG_BIN" ]] && printf '  usable   cut, mix, export, verify\n' || printf '  blocked  cut, mix, export, verify — needs ffmpeg\n'
[[ "$YTDLP_VER" != "absent" ]] && printf '  usable   acquire (references)\n' || printf '  blocked  acquire (references) — needs yt-dlp\n'
[[ "$CHROME_STATE" == "launches" ]] && printf '  usable   render + preview (browser)\n' || printf '  blocked  render + preview (browser) — no launchable Chrome\n'

printf '\n'
if [[ "$REQUIRED_MISSING" -eq 0 ]]; then
  printf 'Every required track is usable.\n'
else
  printf 'A required track is missing. Fix the GAP lines above before starting.\n'
fi
[[ "$FIX" -eq 1 ]] && printf '\nInstall (macOS):  brew install ffmpeg yt-dlp\nInstall (Debian): sudo apt install ffmpeg && pip install -U yt-dlp\nNode 22:          nvm install 22 && nvm use 22\nChrome:           npx hyperframes browser ensure\n'
exit "$REQUIRED_MISSING"
