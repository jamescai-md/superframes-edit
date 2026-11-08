#!/usr/bin/env bash
# analyze.sh — turn a reference video into measurements, so "make it like this"
# becomes numbers instead of adjectives.
#
#   analyze.sh REF.mp4 [--out DIR] [--threshold 0.3] [--fps 1] [--beats]
#
# Writes into DIR (default ./analysis):
#   probe.txt      streams, fps, colour tags, bitrates
#   scenes.txt     detected cut timestamps, with a shot table skeleton
#   audio.txt      integrated loudness, true peak, silence map
#   palette.png    12-colour palette from the whole film
#   sheet.png      contact sheet, 12 frames across the film
#   frames/        one frame per second, scaled for reading
#   ANALYSIS.md    a fillable report with every measurement already in place
#
# Numeric output only. The judgement — what to copy, what to change — stays with
# the person reading ANALYSIS.md.

set -uo pipefail
FFMPEG="${FFMPEG:-ffmpeg}"; FFPROBE="${FFPROBE:-ffprobe}"
die() { printf 'analyze: %s\n' "$*" >&2; exit 2; }

REF="${1:-}"; [[ -n "$REF" && -f "$REF" ]] || die "usage: analyze.sh REF.mp4 [--out DIR]"
shift || true
OUT="analysis"; THRESH="0.3"; FPS="1"; BEATS=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT="${2:-}"; shift 2 ;;
    --threshold) THRESH="${2:-}"; shift 2 ;;
    --fps) FPS="${2:-}"; shift 2 ;;
    --beats) BEATS=1; shift ;;
    *) die "unknown option: $1" ;;
  esac
done

command -v "$FFMPEG" >/dev/null || die "ffmpeg not found"
command -v "$FFPROBE" >/dev/null || die "ffprobe not found"
mkdir -p "$OUT/frames"

dur=$("$FFPROBE" -v error -show_entries format=duration -of default=nw=1:nk=1 "$REF")
rafps=$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=nw=1:nk=1 "$REF")
fps=$(awk -v r="$rafps" 'BEGIN{split(r,a,"/"); if(a[2]+0>0) printf "%.3f", a[1]/a[2]; else printf "%.3f", r+0}')
wh=$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$REF")
vcodec=$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$REF")
pixfmt=$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=pix_fmt -of default=nw=1:nk=1 "$REF")
prim=$( "$FFPROBE" -v error -select_streams v:0 -show_entries stream=color_primaries -of default=nw=1:nk=1 "$REF")
trc=$(  "$FFPROBE" -v error -select_streams v:0 -show_entries stream=color_trc -of default=nw=1:nk=1 "$REF")
crng=$( "$FFPROBE" -v error -select_streams v:0 -show_entries stream=color_range -of default=nw=1:nk=1 "$REF")
acodec=$("$FFPROBE" -v error -select_streams a:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$REF")
srate=$( "$FFPROBE" -v error -select_streams a:0 -show_entries stream=sample_rate -of default=nw=1:nk=1 "$REF")
chans=$( "$FFPROBE" -v error -select_streams a:0 -show_entries stream=channels -of default=nw=1:nk=1 "$REF")

{
  echo "file      $REF"
  echo "duration  $dur"
  echo "fps       $fps"
  echo "size      $wh"
  echo "vcodec    $vcodec ($pixfmt)"
  echo "colour    ${prim:-untagged} / ${trc:-untagged} / ${crng:-untagged}"
  echo "acodec    ${acodec:-none} ${srate:+@ $srate Hz} ${chans:+$chans ch}"
} > "$OUT/probe.txt"

# --- cuts ---------------------------------------------------------------
"$FFMPEG" -hide_banner -nostdin -i "$REF" -vf "select='gt(scene,${THRESH})',showinfo" \
  -an -f null - 2>&1 | grep -oE "pts_time:[0-9.]+" | cut -d: -f2 > "$OUT/scenes.txt" || true
cuts=$(grep -c . "$OUT/scenes.txt" || true)
[[ -n "$cuts" ]] || cuts=0

# A shot table skeleton with lengths already computed.
{
  echo "| # | In | Out | Length | Shot size | Camera | Subject | Transition in | To copy | To change |"
  echo "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"
  prev="0.000"
  i=1
  while read -r t; do
    t=$(awk -v x="$t" 'BEGIN{printf "%.3f", x}')
    len=$(awk -v a="$prev" -v b="$t" 'BEGIN{printf "%.3f", b-a}')
    printf '| %d | %s | %s | %s |  |  |  |  |  |  |\n' "$i" "$prev" "$t" "$len"
    prev="$t"; i=$((i+1))
  done < "$OUT/scenes.txt"
  len=$(awk -v a="$prev" -v d="$dur" 'BEGIN{printf "%.3f", d-a}')
  prev=$(awk -v x="$prev" 'BEGIN{printf "%.3f", x}')
  printf '| %d | %s | %s | %s |  |  |  |  |  |  |\n' "$i" "$prev" "$dur" "$len"
} > "$OUT/shots-table.md"

# --- audio --------------------------------------------------------------
if [[ -n "$acodec" ]]; then
  {
    echo "== loudness =="
    "$FFMPEG" -hide_banner -nostdin -i "$REF" -map 0:a:0 -af loudnorm=print_format=json -f null - 2>&1 | sed -n '/^{/,/^}/p'
    echo
    echo "== silence (noise=-35dB, d=0.35s) =="
    "$FFMPEG" -hide_banner -nostdin -i "$REF" -map 0:a:0 -af "silencedetect=noise=-35dB:d=0.35" -f null - 2>&1 | grep -E "silence_(start|end)"
  } > "$OUT/audio.txt" 2>&1 || true
else
  echo "no audio stream" > "$OUT/audio.txt"
fi

# --- picture ------------------------------------------------------------
"$FFMPEG" -hide_banner -loglevel error -nostdin -i "$REF" \
  -vf "fps=${FPS},scale=160:-1,palettegen=max_colors=12:stats_mode=full" -y "$OUT/palette.png" 2>/dev/null || true
"$FFMPEG" -hide_banner -loglevel error -nostdin -i "$REF" \
  -vf "fps=1,scale=320:-1,tile=4x3" -frames:v 1 -y "$OUT/sheet.png" 2>/dev/null || true
"$FFMPEG" -hide_banner -loglevel error -nostdin -i "$REF" \
  -vf "fps=${FPS},scale=640:-1" -y "$OUT/frames/f-%04d.png" 2>/dev/null || true

# --- beat grid (optional) ----------------------------------------------
if [[ "$BEATS" -eq 1 && -n "$acodec" ]]; then
  # Onsets are a usable proxy for a beat grid without a beat tracker:
  # transients clustered at a stable interval tell you the tempo.
  "$FFMPEG" -hide_banner -nostdin -i "$REF" -map 0:a:0 \
    -af "highpass=f=120,lowpass=f=8000,silencedetect=noise=-22dB:d=0.12" -f null - 2>&1 \
    | grep -oE "silence_end: [0-9.]+" | awk '{print $2}' > "$OUT/onsets.txt" || true
fi

# --- report -------------------------------------------------------------
loud=$(sed -n 's/.*"input_i" : "\([^"]*\)".*/\1/p' "$OUT/audio.txt" | head -1)
peak=$(sed -n 's/.*"input_tp" : "\([^"]*\)".*/\1/p' "$OUT/audio.txt" | head -1)
lra=$( sed -n 's/.*"input_lra" : "\([^"]*\)".*/\1/p' "$OUT/audio.txt" | head -1)
avglen=$(awk -v d="$dur" -v c="$cuts" 'BEGIN{ if (c>0) printf "%.2f", d/(c+1); else printf "%.2f", d }')
cutrate=$(awk -v c="$cuts" -v d="$dur" 'BEGIN{ if (d>0) printf "%.2f", c/d; else print 0 }')

cat > "$OUT/ANALYSIS.md" <<EOF
# ANALYSIS — $(basename "$REF")

Generated by \`superframes-edit\`. Every number below was measured from the file,
not estimated. Fill the judgement columns by hand.

## Measured

| Property | Value |
| --- | --- |
| Duration | ${dur} s |
| Frame rate | ${fps} fps |
| Dimensions | ${wh} |
| Video | ${vcodec} (${pixfmt}) |
| Colour tags | ${prim:-untagged} / ${trc:-untagged} / ${crng:-untagged} |
| Audio | ${acodec:-none} ${srate:+@ $srate Hz} ${chans:+$chans ch} |
| Integrated loudness | ${loud:-n/a} LUFS |
| True peak | ${peak:-n/a} dBTP |
| Loudness range | ${lra:-n/a} LU |
| Detected cuts | ${cuts} (scene threshold ${THRESH}) |
| Average shot length | ${avglen} s |
| Cut rate | ${cutrate} cuts per second |

## Shot table

$(cat "$OUT/shots-table.md")

## Motion vocabulary

Name each motion in production language and give it a number, so it can be built.

| Observed | Name | Number to build |
| --- | --- | --- |
|  |  |  |

## Palette and grade

Open \`palette.png\`. Record six values with roles.

| Role | Hex |
| --- | --- |
| Background |  |
| Primary |  |
| Accent |  |
| Text |  |
| Shadow |  |
| Highlight |  |

Grade name (neutral, teal-orange, bleached, monochrome, warm-print, cyan-tech):

## Type and layout

- Cap height of the main headline: ___ px at ${wh}
- Edge margin used: ___ % of width
- Families (by shape): ___
- Substitutions needed for licensed fonts: ___

## Audio

- Does the cut land on the beat? ___
- Voice above or under the music? ___
- Silence map in \`audio.txt\`: usable for a voiceover cut? ___

## What to copy, what to change

Copy the system: pacing, palette structure, motion grammar, type scale.

Change the content, the words, the specifics, the marks. A frame-for-frame
rebuild of someone else's film is a legal and ethical problem; state the
difference explicitly here and in DELIVERY.md.

- Copying:
- Changing:
- Licence class of the reference: reference-only / licensed / cc-by
EOF

printf 'analyze: wrote %s\n' "$OUT"
printf '  probe.txt scenes.txt audio.txt palette.png sheet.png frames/ ANALYSIS.md\n' >&2
printf '  %s cuts detected at threshold %s; average shot %s s\n' "$cuts" "$THRESH" "$avglen" >&2
