#!/usr/bin/env bash
# cut.sh — the FFmpeg stage as a job runner: cut, join, mix, normalise, export.
#
# It exists because the same six operations go wrong the same six ways every time:
# re-encode-vs-stream-copy, keyframe drift, mismatched sample rates, loudness
# measured after concatenation instead of before, untagged colour, and silent
# streams dropped on concat. Each subcommand encodes the fix.
#
#   cut.sh probe FILE
#   cut.sh trim IN OUT START [DURATION]        frame-exact cut, re-encodes
#   cut.sh fast-trim IN OUT START [DURATION]   stream copy, keyframe-aligned
#   cut.sh concat OUT FILE...                  join dissimilar files safely
#   cut.sh normalise IN OUT [LUFS] [TP]        two-pass EBU R128 loudness
#   cut.sh mix OUT VOICE MUSIC [MUSIC_GAIN] [DUCK]  voiceover over a bed with ducking
#   cut.sh extract-audio IN OUT                audio only, 48 kHz PCM
#   cut.sh frames IN OUTDIR FPS                contact sheet + stills
#   cut.sh export IN OUT [preset]              delivery encodes: master|web|social|vertical
#   cut.sh conform IN OUT                      force CFR fps + 48 kHz audio
#   cut.sh speed IN OUT FACTOR                 change speed for video and audio together
#   cut.sh burn-subs IN OUT SUBS.srt           hardsub with readable styling
#
# Conventions: times are seconds or HH:MM:SS.mmm. All output audio is 48 kHz.
# Every command prints the ffmpeg invocation it runs, so the job is replayable.

set -uo pipefail
FFMPEG="${FFMPEG:-ffmpeg}"; FFPROBE="${FFPROBE:-ffprobe}"
die() { printf 'cut: %s\n' "$*" >&2; exit 2; }
need() { command -v "$1" >/dev/null || die "$1 not found; install ffmpeg"; }
need "$FFMPEG"; need "$FFPROBE"

run() { printf '+ %s\n' "$*" >&2; "$@"; }

# Ask the file what it is rather than trusting the extension.
probe_dim()  { "$FFPROBE" -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$1"; }
probe_fps()  { local r; r=$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=nw=1:nk=1 "$1"); awk -v r="$r" 'BEGIN{split(r,a,"/"); if(a[2]+0>0) printf "%.3f", a[1]/a[2]; else printf "%.3f", r+0}'; }
probe_dur()  { "$FFPROBE" -v error -show_entries format=duration -of default=nw=1:nk=1 "$1"; }
has_audio()  { [[ -n "$("$FFPROBE" -v error -select_streams a:0 -show_entries stream=codec_type -of default=nw=1:nk=1 "$1")" ]]; }
probe_srate(){ "$FFPROBE" -v error -select_streams a:0 -show_entries stream=sample_rate -of default=nw=1:nk=1 "$1"; }

cmd="${1:-}"; [[ -n "$cmd" ]] || die "usage: cut.sh <subcommand> …   (see the header of this file)"
shift || true

case "$cmd" in

probe)
  f="${1:-}"; [[ -f "$f" ]] || die "no such file"
  printf 'file      %s\n' "$f"
  printf 'duration  %s s\n' "$(probe_dur "$f")"
  printf 'fps       %s\n' "$(probe_fps "$f")"
  printf 'size      %s\n' "$(probe_dim "$f")"
  printf 'vcodec    %s\n' "$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$f")"
  printf 'pixfmt    %s\n' "$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=pix_fmt -of default=nw=1:nk=1 "$f")"
  printf 'colour    %s / %s / %s\n' \
    "$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=color_primaries -of default=nw=1:nk=1 "$f")" \
    "$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=color_trc -of default=nw=1:nk=1 "$f")" \
    "$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=color_range -of default=nw=1:nk=1 "$f")"
  if has_audio "$f"; then
    printf 'acodec    %s @ %s Hz\n' "$("$FFPROBE" -v error -select_streams a:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$f")" "$(probe_srate "$f")"
  else
    printf 'acodec    (none)\n'
  fi
  ;;

trim)
  in="${1:-}"; out="${2:-}"; start="${3:-}"; dur="${4:-}"
  [[ -f "$in" ]] || die "no such input: $in"
  [[ -n "$start" ]] || die "trim needs a start time"
  [[ -n "$dur" ]] || die "trim needs a duration (use fast-trim when you want the rest of the file)"
  # -ss before -i seeks fast and decodes forward to the exact frame; re-encoding
  # is what makes it frame-exact. Stream copy would snap to the previous keyframe.
  run "$FFMPEG" -hide_banner -y -ss "$start" -i "$in" -t "$dur" \
    -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -fps_mode cfr \
    -c:a aac -b:a 192k -ar 48000 -shortest -movflags +faststart "$out"
  ;;

fast-trim)
  in="${1:-}"; out="${2:-}"; start="${3:-}"; dur="${4:-}"
  [[ -f "$in" ]] || die "no such input: $in"
  # Copy the streams: instant and lossless, but the cut snaps to the nearest
  # preceding keyframe, so the start can be off by up to a GOP.
  args=(-hide_banner -y -ss "$start" -i "$in")
  [[ -n "$dur" ]] && args+=(-t "$dur")
  args+=(-map 0 -c copy -avoid_negative_ts make_zero -movflags +faststart "$out")
  run "$FFMPEG" "${args[@]}"
  ;;

concat)
  out="${1:-}"; shift || true
  [[ $# -ge 2 ]] || die "concat needs at least two input files"
  for f in "$@"; do [[ -f "$f" ]] || die "no such input: $f"; done
  # Normalise every input to one size, one fps, one pixel format and one audio
  # layout, then join with the concat filter. The concat *demuxer* is faster but
  # demands byte-compatible streams, which real footage never has. A missing
  # audio track is replaced by silence so the segments stay aligned.
  dim=$(probe_dim "$1"); fps=$(probe_fps "$1")
  w=${dim%x*}; h=${dim#*x}
  anyaudio=0; for f in "$@"; do has_audio "$f" && anyaudio=1; done
  filters=""; pairs=""; idx=0
  for f in "$@"; do
    filters+="[${idx}:v:0]scale=${w}:${h}:force_original_aspect_ratio=decrease,"
    filters+="pad=${w}:${h}:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=${fps},format=yuv420p[v${idx}];"
    if [[ "$anyaudio" -eq 1 ]]; then
      if has_audio "$f"; then
        filters+="[${idx}:a:0]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo[a${idx}];"
      else
        d=$(probe_dur "$f")
        filters+="anullsrc=r=48000:cl=stereo,atrim=0:${d},aformat=sample_fmts=fltp:channel_layouts=stereo[a${idx}];"
      fi
    fi
    pairs+="[v${idx}]"; [[ "$anyaudio" -eq 1 ]] && pairs+="[a${idx}]"
    idx=$((idx+1))
  done
  inputs=(); for f in "$@"; do inputs+=(-i "$f"); done
  if [[ "$anyaudio" -eq 1 ]]; then
    filters+="${pairs}concat=n=${idx}:v=1:a=1[vout][aout]"
    run "$FFMPEG" -hide_banner -y "${inputs[@]}" -filter_complex "$filters" \
      -map '[vout]' -map '[aout]' -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p \
      -fps_mode cfr -c:a aac -b:a 192k -ar 48000 -movflags +faststart "$out"
  else
    filters+="${pairs}concat=n=${idx}:v=1:a=0[vout]"
    run "$FFMPEG" -hide_banner -y "${inputs[@]}" -filter_complex "$filters" \
      -map '[vout]' -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p \
      -fps_mode cfr -movflags +faststart "$out"
  fi
  ;;

normalise)
  in="${1:-}"; out="${2:-}"; lufs="${3:--14}"; tp="${4:--1.0}"
  [[ -f "$in" ]] || die "no such input: $in"
  has_audio "$in" || die "normalise needs an audio stream"
  # Pass 1 measures. Pass 2 applies the measurement so the result is accurate
  # and, with linear=true, no dynamic pumping is introduced.
  m=$("$FFMPEG" -hide_banner -nostdin -i "$in" -map 0:a:0 \
      -af "loudnorm=I=${lufs}:TP=${tp}:LRA=11:print_format=json" -f null - 2>&1 \
      | sed -n '/^{/,/^}/p')
  [[ -n "$m" ]] || die "loudnorm produced no measurement"
  gv() { printf '%s' "$m" | sed -n "s/.*\"$1\" : \"\([^\"]*\)\".*/\1/p"; }
  MI=$(gv input_i); ML=$(gv input_lra); MT=$(gv input_tp); MTH=$(gv input_thresh); OFF=$(gv target_offset)
  dur=$(probe_dur "$in")
  # -shortest + an explicit -t: re-encoding audio alone can pad and lengthen the
  # file by a fraction of a second, which then fails a duration check.
  run "$FFMPEG" -hide_banner -y -i "$in" -map 0:v? -map 0:a:0 -c:v copy \
    -af "loudnorm=I=${lufs}:TP=${tp}:LRA=11:measured_I=${MI}:measured_LRA=${ML}:measured_TP=${MT}:measured_thresh=${MTH}:offset=${OFF}:linear=true" \
    -ar 48000 -c:a aac -b:a 256k -t "$dur" -shortest -movflags +faststart "$out"
  printf 'measured %s LUFS → target %s LUFS\n' "$MI" "$lufs" >&2
  ;;

mix)
  out="${1:-}"; voice="${2:-}"; music="${3:-}"; gain="${4:--18}"; duck="${5:-0.25}"
  [[ -f "$voice" && -f "$music" ]] || die "mix needs a voice file and a music file"
  # sidechaincompress keys the music off the voice: music drops while the voice
  # speaks and comes back on its own. No manual gain automation needed.
  run "$FFMPEG" -hide_banner -y -i "$voice" -stream_loop -1 -i "$music" \
    -filter_complex "\
[0:a]aresample=48000,aformat=channel_layouts=stereo,asplit=2[vo][key];\
[1:a]aresample=48000,aformat=channel_layouts=stereo,volume=${gain}dB[bed];\
[bed][key]sidechaincompress=threshold=0.03:ratio=8:attack=20:release=400:makeup=1[ducked];\
[vo][ducked]amix=inputs=2:duration=first:dropout_transition=2:normalize=0[aout]" \
    -map '[aout]' $([[ -n "${MIX_VIDEO:-}" ]] && echo "-map ${MIX_VIDEO}") \
    -c:a aac -b:a 256k -ar 48000 -shortest -movflags +faststart "$out"
  printf 'ducked the bed by %.0f dB under the voice (ratio 8, release 400 ms)\n' "$(awk -v g="$gain" 'BEGIN{print -g}')" >&2
  ;;

extract-audio)
  in="${1:-}"; out="${2:-}"
  [[ -f "$in" ]] || die "no such input: $in"
  run "$FFMPEG" -hide_banner -y -i "$in" -vn -ac 2 -ar 48000 -c:a pcm_s16le "$out"
  ;;

frames)
  in="${1:-}"; dir="${2:-frames}"; fps="${3:-1}"
  [[ -f "$in" ]] || die "no such input: $in"
  mkdir -p "$dir"
  run "$FFMPEG" -hide_banner -y -i "$in" -vf "fps=${fps},scale=480:-1" "$dir/frame-%04d.png"
  # A single sheet to read the whole film at a glance: 12 frames, 4 across.
  run "$FFMPEG" -hide_banner -y -i "$in" -vf "fps=1,scale=320:-1,tile=4x3" -frames:v 1 "$dir/sheet.png"
  printf 'wrote %s stills + %s/sheet.png\n' "$(find "$dir" -name 'frame-*.png' | wc -l | tr -d ' ')" "$dir" >&2
  ;;

conform)
  in="${1:-}"; out="${2:-}"; fps="${3:-30}"
  [[ -f "$in" ]] || die "no such input: $in"
  # Variable frame rate is the root cause of most drift and desync. This forces
  # constant frame rate and one audio layout before anything else touches it.
  if has_audio "$in"; then
    run "$FFMPEG" -hide_banner -y -i "$in" -vf "fps=${fps}" -fps_mode cfr \
      -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p \
      -af "aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo" \
      -c:a aac -b:a 192k -ar 48000 -movflags +faststart "$out"
  else
    run "$FFMPEG" -hide_banner -y -i "$in" -vf "fps=${fps}" -fps_mode cfr \
      -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -movflags +faststart "$out"
  fi
  ;;

speed)
  in="${1:-}"; out="${2:-}"; factor="${3:-}"
  [[ -f "$in" && -n "$factor" ]] || die "speed needs an input and a factor"
  # atempo accepts 0.5–100 per instance, so chain instances for extreme factors.
  achain="atempo=${factor}"
  if awk -v f="$factor" 'BEGIN{exit !(f<0.5)}'; then
    half=$(awk -v f="$factor" 'BEGIN{printf "%.4f", f/0.5}')
    achain="atempo=0.5,atempo=${half}"
  elif awk -v f="$factor" 'BEGIN{exit !(f>2)}'; then
    rest=$(awk -v f="$factor" 'BEGIN{printf "%.4f", f/2}')
    achain="atempo=2,atempo=${rest}"
  fi
  pts="PTS/${factor}"
  if has_audio "$in"; then
    run "$FFMPEG" -hide_banner -y -i "$in" -filter_complex "[0:v]setpts=$pts[v];[0:a]${achain}[a]" \
      -map '[v]' -map '[a]' -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p \
      -c:a aac -b:a 192k -ar 48000 -movflags +faststart "$out"
  else
    run "$FFMPEG" -hide_banner -y -i "$in" -vf "setpts=$pts" \
      -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -movflags +faststart "$out"
  fi
  ;;

burn-subs)
  in="${1:-}"; out="${2:-}"; subs="${3:-}"
  [[ -f "$in" && -f "$subs" ]] || die "burn-subs needs an input and a subtitle file"
  # Escape the path for the filtergraph: colons and commas break it.
  esc=$(printf '%s' "$subs" | sed -e 's/\\/\\\\/g' -e "s/:/\\\\:/g" -e "s/'/\\\\'/g")
  run "$FFMPEG" -hide_banner -y -i "$in" \
    -vf "subtitles='${esc}':force_style='FontName=Inter,Fontsize=20,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,BorderStyle=1,Outline=2,Shadow=0,MarginV=64,Alignment=2'" \
    -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -c:a copy "$out"
  ;;

export)
  in="${1:-}"; out="${2:-}"; preset="${3:-master}"
  [[ -f "$in" ]] || die "no such input: $in"
  fps=$(probe_fps "$in")
  case "$preset" in
    master)
      # Bit-exact-ish intermediate: nearly lossless, fast to decode, big files.
      run "$FFMPEG" -hide_banner -y -i "$in" -c:v libx264 -preset slow -crf 12 \
        -pix_fmt yuv420p -profile:v high -level 4.2 -fps_mode cfr \
        -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
        -c:a aac -b:a 320k -ar 48000 -movflags +faststart "$out" ;;
    web)
      run "$FFMPEG" -hide_banner -y -i "$in" -c:v libx264 -preset slow -crf 19 \
        -pix_fmt yuv420p -profile:v high -level 4.1 -fps_mode cfr -g $(( ${fps%.*} * 2 )) \
        -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
        -c:a aac -b:a 192k -ar 48000 -movflags +faststart "$out" ;;
    social)
      # 1080p H.264 + AAC, the combination every platform re-encodes from cleanly.
      run "$FFMPEG" -hide_banner -y -i "$in" \
        -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,setsar=1" \
        -c:v libx264 -preset slow -crf 21 -pix_fmt yuv420p -profile:v high -level 4.1 -fps_mode cfr \
        -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
        -c:a aac -b:a 192k -ar 48000 -movflags +faststart "$out" ;;
    vertical)
      run "$FFMPEG" -hide_banner -y -i "$in" \
        -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1" \
        -c:v libx264 -preset slow -crf 21 -pix_fmt yuv420p -profile:v high -level 4.1 -fps_mode cfr \
        -c:a aac -b:a 192k -ar 48000 -movflags +faststart "$out" ;;
    square)
      run "$FFMPEG" -hide_banner -y -i "$in" \
        -vf "scale=1080:1080:force_original_aspect_ratio=increase,crop=1080:1080,setsar=1" \
        -c:v libx264 -preset slow -crf 21 -pix_fmt yuv420p -fps_mode cfr \
        -c:a aac -b:a 192k -ar 48000 -movflags +faststart "$out" ;;
    *) die "unknown preset '$preset' (master, web, social, vertical, square)" ;;
  esac
  ;;

*) die "unknown subcommand '$cmd'" ;;
esac
