#!/usr/bin/env bash
# verify.sh — the delivery gate. One command that answers "is this file shipable?".
#
# Usage:
#   verify.sh FILE [options]
#
#   --expect-duration S     fail if duration differs by more than --tolerance (default 0.15 s)
#   --expect-size WxH       fail if video dimensions differ
#   --expect-fps F          fail if frame rate differs by more than 0.01
#   --against REF           compare pixels with REF (SSIM + PSNR, same duration expected)
#   --audio                 check loudness, true peak, clipping, and A/V start offset
#   --loudness-target LUFS  integrated loudness target (default -14)
#   --peak-ceiling DBTP     true peak ceiling (default -1.0)
#   --black                 flag fully black runs longer than --black-min seconds (default 0.5)
#   --freeze                flag frozen runs longer than --freeze-min seconds (default 2.0)
#   --frames DIR            dump one frame per segment into DIR for human inspection
#   --json                  machine-readable summary on stdout
#   --quiet                 only print FAIL and the summary
#
# Exit codes: 0 all pass, 1 at least one FAIL, 2 usage or environment error.
#
# Every check prints PASS / WARN / FAIL. FAIL means do not deliver. WARN means
# deliverable with a stated reason, and must be recorded in DELIVERY.md.

set -uo pipefail

FFMPEG="${FFMPEG:-ffmpeg}"
FFPROBE="${FFPROBE:-ffprobe}"

die() { printf 'verify: %s\n' "$*" >&2; exit 2; }

[[ $# -ge 1 ]] || die "usage: verify.sh FILE [options]"
FILE="$1"; shift
[[ -f "$FILE" ]] || die "no such file: $FILE"
command -v "$FFPROBE" >/dev/null || die "ffprobe not found; install ffmpeg or set FFPROBE"
command -v "$FFMPEG"  >/dev/null || die "ffmpeg not found; install ffmpeg or set FFMPEG"

EXPECT_DURATION=""; EXPECT_SIZE=""; EXPECT_FPS=""; AGAINST=""
TOLERANCE="0.15"; DO_AUDIO=0; DO_BLACK=0; DO_FREEZE=0
LOUD_TARGET="-14"; PEAK_CEIL="-1.0"
BLACK_MIN="0.5"; FREEZE_MIN="2.0"
FRAMES_DIR=""; JSON=0; QUIET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --expect-duration) EXPECT_DURATION="${2:-}"; shift 2 ;;
    --expect-size)     EXPECT_SIZE="${2:-}"; shift 2 ;;
    --expect-fps)      EXPECT_FPS="${2:-}"; shift 2 ;;
    --against)         AGAINST="${2:-}"; shift 2 ;;
    --tolerance)       TOLERANCE="${2:-}"; shift 2 ;;
    --audio)           DO_AUDIO=1; shift ;;
    --loudness-target) LOUD_TARGET="${2:-}"; shift 2 ;;
    --peak-ceiling)    PEAK_CEIL="${2:-}"; shift 2 ;;
    --black)           DO_BLACK=1; shift ;;
    --black-min)       BLACK_MIN="${2:-}"; shift 2 ;;
    --freeze)          DO_FREEZE=1; shift ;;
    --freeze-min)      FREEZE_MIN="${2:-}"; shift 2 ;;
    --frames)          FRAMES_DIR="${2:-}"; shift 2 ;;
    --json)            JSON=1; shift ;;
    --quiet)           QUIET=1; shift ;;
    -h|--help)         sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)                 die "unknown option: $1" ;;
  esac
done

PASS=0; WARN=0; FAIL=0
declare -a RESULTS=()

# verdict <PASS|WARN|FAIL> <check-name> <detail>
verdict() {
  local level="$1" name="$2" detail="$3"
  case "$level" in
    PASS) PASS=$((PASS+1)) ;;
    WARN) WARN=$((WARN+1)) ;;
    FAIL) FAIL=$((FAIL+1)) ;;
  esac
  RESULTS+=("${level}|${name}|${detail}")
  if [[ "$QUIET" -eq 0 || "$level" != "PASS" ]]; then
    printf '%-4s  %-22s %s\n' "$level" "$name" "$detail"
  fi
}

num() { awk -v a="$1" -v b="$2" 'BEGIN{ exit (a>b) ? 0 : 1 }'; }
absdiff() { awk -v a="$1" -v b="$2" 'BEGIN{ d=a-b; if (d<0) d=-d; printf "%.4f", d }'; }
cmpgt()  { awk -v a="$1" -v b="$2" 'BEGIN{ exit (a>b) ? 0 : 1 }'; }

probe() { "$FFPROBE" -v error "$@" ; }

# ---------- 1. container and stream sanity ----------
DURATION=$(probe -show_entries format=duration -of default=nw=1:nk=1 "$FILE" 2>/dev/null)
[[ -n "$DURATION" && "$DURATION" != "N/A" ]] || DURATION=0
SIZE=$(probe -show_entries format=size -of default=nw=1:nk=1 "$FILE" 2>/dev/null)
[[ -n "$SIZE" ]] || SIZE=0
FORMAT=$(probe -show_entries format=format_name -of default=nw=1:nk=1 "$FILE" 2>/dev/null)

if [[ "$SIZE" -le 0 ]]; then
  verdict FAIL "file" "size is ${SIZE} bytes; the file is empty"
else
  verdict PASS "file" "$(awk -v s="$SIZE" 'BEGIN{printf "%.2f MB", s/1048576}') ${FORMAT}"
fi

VCODEC=$(probe -select_streams v:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$FILE")
WIDTH=$(probe -select_streams v:0 -show_entries stream=width -of default=nw=1:nk=1 "$FILE")
HEIGHT=$(probe -select_streams v:0 -show_entries stream=height -of default=nw=1:nk=1 "$FILE")
RAFPS=$(probe -select_streams v:0 -show_entries stream=r_frame_rate -of default=nw=1:nk=1 "$FILE")
PIXFMT=$(probe -select_streams v:0 -show_entries stream=pix_fmt -of default=nw=1:nk=1 "$FILE")
NBF=$(probe -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of default=nw=1:nk=1 "$FILE" 2>/dev/null)

if [[ -z "$VCODEC" ]]; then
  verdict FAIL "video-stream" "no video stream found"
  FPS=0
else
  FPS=$(awk -v r="$RAFPS" 'BEGIN{ split(r,a,"/"); if (a[2]+0>0) printf "%.3f", a[1]/a[2]; else printf "%.3f", r+0 }')
  verdict PASS "video-stream" "${VCODEC} ${WIDTH}x${HEIGHT} ${FPS} fps ${PIXFMT}"
fi

# ---------- 2. duration ----------
if [[ -n "$EXPECT_DURATION" ]]; then
  D=$(absdiff "$DURATION" "$EXPECT_DURATION")
  if cmpgt "$D" "$TOLERANCE"; then
    verdict FAIL "duration" "got ${DURATION}s, expected ${EXPECT_DURATION}s (tolerance ${TOLERANCE}s)"
  else
    verdict PASS "duration" "${DURATION}s (expected ${EXPECT_DURATION}s)"
  fi
else
  if cmpgt "0" "$DURATION"; then verdict FAIL "duration" "zero-length file"; else verdict PASS "duration" "${DURATION}s"; fi
fi

# ---------- 3. dimensions and fps ----------
if [[ -n "$EXPECT_SIZE" ]]; then
  if [[ "${WIDTH}x${HEIGHT}" == "$EXPECT_SIZE" ]]; then
    verdict PASS "dimensions" "${WIDTH}x${HEIGHT}"
  else
    verdict FAIL "dimensions" "got ${WIDTH}x${HEIGHT}, expected ${EXPECT_SIZE}"
  fi
fi

if [[ -n "$EXPECT_FPS" ]]; then
  D=$(absdiff "$FPS" "$EXPECT_FPS")
  if cmpgt "$D" "0.01"; then
    verdict FAIL "fps" "got ${FPS}, expected ${EXPECT_FPS} (re-encoded at the wrong rate?)"
  else
    verdict PASS "fps" "${FPS}"
  fi
fi

# ---------- 4. frame count agrees with duration ----------
if [[ -n "$NBF" && "$NBF" -gt 0 && "$FPS" != "0.000" ]]; then
  EXPECTED_FRAMES=$(awk -v d="$DURATION" -v f="$FPS" 'BEGIN{printf "%d", d*f}')
  DIFF=$(awk -v a="$NBF" -v b="$EXPECTED_FRAMES" 'BEGIN{ d=a-b; if (d<0) d=-d; printf "%d", d }')
  # A couple of frames of slack: container duration covers padded last frames.
  if [[ "$DIFF" -le 2 ]]; then
    verdict PASS "frame-count" "${NBF} frames ≈ ${EXPECTED_FRAMES} expected"
  elif [[ "$DIFF" -le 10 ]]; then
    verdict WARN "frame-count" "${NBF} frames vs ${EXPECTED_FRAMES} expected; check for a trailing hold"
  else
    verdict FAIL "frame-count" "${NBF} frames vs ${EXPECTED_FRAMES} expected; the render ended early or overran"
  fi
fi

# ---------- 5. colour tags ----------
CRANGE=$(probe -select_streams v:0 -show_entries stream=color_range -of default=nw=1:nk=1 "$FILE")
CSPACE=$(probe -select_streams v:0 -show_entries stream=color_space -of default=nw=1:nk=1 "$FILE")
if [[ -z "$CRANGE" || "$CRANGE" == "unknown" || -z "$CSPACE" || "$CSPACE" == "unknown" ]]; then
  verdict WARN "colour-tags" "untagged (${CSPACE:-none}/${CRANGE:-none}); players may guess and shift colour"
else
  verdict PASS "colour-tags" "${CSPACE}/${CRANGE}"
fi

# ---------- 6. black and freeze runs ----------
if [[ "$DO_BLACK" -eq 1 ]]; then
  BLACK=$( { "$FFMPEG" -hide_banner -nostdin -i "$FILE" -vf "blackdetect=d=${BLACK_MIN}:pix_th=0.10" -an -f null - 2>&1 || true; } | grep -c "black_start" || true)
  if [[ "${BLACK:-0}" -gt 0 ]]; then
    verdict WARN "black-runs" "${BLACK} black run(s) ≥${BLACK_MIN}s; intended for a title card, a defect anywhere else"
  else
    verdict PASS "black-runs" "none ≥${BLACK_MIN}s"
  fi
fi

if [[ "$DO_FREEZE" -eq 1 ]]; then
  FRZ=$( { "$FFMPEG" -hide_banner -nostdin -i "$FILE" -vf "freezedetect=n=-60dB:d=${FREEZE_MIN}" -an -f null - 2>&1 || true; } | grep -c "freeze_start" || true)
  if [[ "${FRZ:-0}" -gt 0 ]]; then
    verdict WARN "freeze-runs" "${FRZ} frozen run(s) ≥${FREEZE_MIN}s; a still frame on purpose, a stuck render otherwise"
  else
    verdict PASS "freeze-runs" "none ≥${FREEZE_MIN}s"
  fi
fi

# ---------- 7. audio ----------
ACODEC=$(probe -select_streams a:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$FILE")
if [[ "$DO_AUDIO" -eq 1 ]]; then
  if [[ -z "$ACODEC" ]]; then
    verdict FAIL "audio" "no audio stream, but --audio was requested"
  else
    SRATE=$(probe -select_streams a:0 -show_entries stream=sample_rate -of default=nw=1:nk=1 "$FILE")
    CH=$(probe -select_streams a:0 -show_entries stream=channels -of default=nw=1:nk=1 "$FILE")
    if [[ "$SRATE" != "48000" ]]; then
      verdict WARN "sample-rate" "${SRATE} Hz; 48000 is the safe default for video delivery"
    else
      verdict PASS "sample-rate" "48000 Hz, ${CH} ch, ${ACODEC}"
    fi

    LOUD_JSON=$( { "$FFMPEG" -hide_banner -nostdin -i "$FILE" -map 0:a:0 \
      -af "loudnorm=print_format=json" -f null - 2>&1 || true; } | sed -n '/^{/,/^}/p')
    if [[ -n "$LOUD_JSON" ]]; then
      I=$(printf '%s' "$LOUD_JSON" | sed -n 's/.*"input_i" : "\([^"]*\)".*/\1/p')
      TP=$(printf '%s' "$LOUD_JSON" | sed -n 's/.*"input_tp" : "\([^"]*\)".*/\1/p')
      LRA=$(printf '%s' "$LOUD_JSON" | sed -n 's/.*"input_lra" : "\([^"]*\)".*/\1/p')
      IDIFF=$(absdiff "$I" "$LOUD_TARGET")
      if cmpgt "$IDIFF" "3.0"; then
        verdict FAIL "loudness" "${I} LUFS vs target ${LOUD_TARGET} LUFS (off by ${IDIFF}); run the normalise pass"
      elif cmpgt "$IDIFF" "1.0"; then
        verdict WARN "loudness" "${I} LUFS vs target ${LOUD_TARGET} LUFS (off by ${IDIFF}); acceptable, note it"
      else
        verdict PASS "loudness" "${I} LUFS (target ${LOUD_TARGET}), LRA ${LRA}"
      fi
      if cmpgt "$TP" "$PEAK_CEIL"; then
        verdict FAIL "true-peak" "${TP} dBTP over the ${PEAK_CEIL} dBTP ceiling; inter-sample clipping"
      else
        verdict PASS "true-peak" "${TP} dBTP (ceiling ${PEAK_CEIL})"
      fi
    else
      verdict WARN "loudness" "loudnorm produced no measurement; check the audio stream"
    fi

    # A/V start offset: when does each stream actually begin?
    VSTART=$(probe -select_streams v:0 -show_entries stream=start_time -of default=nw=1:nk=1 "$FILE")
    ASTART=$(probe -select_streams a:0 -show_entries stream=start_time -of default=nw=1:nk=1 "$FILE")
    [[ -n "$VSTART" ]] || VSTART=0
    [[ -n "$ASTART" ]] || ASTART=0
    OFFSET=$(absdiff "$VSTART" "$ASTART")
    OFFSET_FRAMES=$(awk -v o="$OFFSET" -v f="$FPS" 'BEGIN{ if (f>0) printf "%.2f", o*f; else print "0" }')
    if cmpgt "$OFFSET" "0.034"; then
      verdict WARN "av-sync-start" "audio starts ${OFFSET}s (${OFFSET_FRAMES} frames) after video; verify against a sync marker"
    else
      verdict PASS "av-sync-start" "within one frame (${OFFSET}s)"
    fi
  fi
fi

# ---------- 8. pixel comparison against a reference ----------
if [[ -n "$AGAINST" ]]; then
  if [[ ! -f "$AGAINST" ]]; then
    verdict FAIL "compare" "reference not found: $AGAINST"
  else
    SIZE_A=$(probe -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$AGAINST")
    SIZE_B="${WIDTH}x${HEIGHT}"
    if [[ "$SIZE_A" != "$SIZE_B" ]]; then
      verdict WARN "compare-size" "reference is ${SIZE_A}, target is ${SIZE_B}; scaling reference to compare"
      SCALE_REF="scale=${WIDTH}:${HEIGHT},setsar=1"
    else
      SCALE_REF="setsar=1"
    fi
    OUT=$( { "$FFMPEG" -hide_banner -nostdin -i "$FILE" -i "$AGAINST" \
      -filter_complex "[1:v]${SCALE_REF}[r];[0:v]setsar=1[t];[t][r]ssim=stats_file=-" \
      -an -f null - 2>&1 || true; } | grep -oE "All:[0-9.]+" | tail -1 | cut -d: -f2)
    PSNR=$( { "$FFMPEG" -hide_banner -nostdin -i "$FILE" -i "$AGAINST" \
      -filter_complex "[1:v]${SCALE_REF}[r];[0:v]setsar=1[t];[t][r]psnr" \
      -an -f null - 2>&1 || true; } | grep -oE "average:[0-9.]+" | tail -1 | cut -d: -f2)
    if [[ -n "$OUT" ]]; then
      if cmpgt "0.95" "$OUT"; then
        verdict PASS "ssim-vs-ref" "SSIM ${OUT} (≥0.95: visually equivalent), PSNR ${PSNR:-n/a} dB"
      elif cmpgt "0.85" "$OUT"; then
        verdict WARN "ssim-vs-ref" "SSIM ${OUT} (0.85–0.95: close, check the divergent shots), PSNR ${PSNR:-n/a} dB"
      else
        verdict FAIL "ssim-vs-ref" "SSIM ${OUT} (<0.85: not the same film); inspect frames side by side"
      fi
    else
      verdict WARN "ssim-vs-ref" "comparison produced no score (duration or stream mismatch)"
    fi
  fi
fi

# ---------- 9. frames for human inspection ----------
if [[ -n "$FRAMES_DIR" ]]; then
  mkdir -p "$FRAMES_DIR"
  SEGMENTS=6
  for i in $(seq 0 $((SEGMENTS-1))); do
    T=$(awk -v d="$DURATION" -v i="$i" -v n="$SEGMENTS" 'BEGIN{printf "%.3f", (d*(i+0.5))/n}')
    "$FFMPEG" -hide_banner -loglevel error -nostdin -ss "$T" -i "$FILE" -frames:v 1 \
      -y "${FRAMES_DIR}/frame-${i}.png" 2>/dev/null || true
  done
  COUNT=$(find "$FRAMES_DIR" -name 'frame-*.png' | wc -l | tr -d ' ')
  if [[ "$COUNT" -eq "$SEGMENTS" ]]; then
    verdict PASS "frames" "${COUNT} frames in ${FRAMES_DIR}; open them before delivering"
  else
    verdict WARN "frames" "only ${COUNT}/${SEGMENTS} frames extracted"
  fi
  "$FFMPEG" -hide_banner -loglevel error -nostdin -i "$FILE" \
    -vf "fps=1,scale=320:-1,tile=4x3" -frames:v 1 -y "${FRAMES_DIR}/sheet.png" 2>/dev/null || true
  [[ -f "${FRAMES_DIR}/sheet.png" ]] && verdict PASS "contact-sheet" "${FRAMES_DIR}/sheet.png"
fi

# ---------- summary ----------
if [[ "$JSON" -eq 1 ]]; then
  printf '{'
  printf '"file":"%s","duration":%s,"size":%s,"width":%s,"height":%s,"fps":%s,' \
    "${FILE//\"/\\\"}" "${DURATION:-0}" "${SIZE:-0}" "${WIDTH:-0}" "${HEIGHT:-0}" "${FPS:-0}"
  printf '"pass":%d,"warn":%d,"fail":%d,"results":[' "$PASS" "$WARN" "$FAIL"
  first=1
  for r in "${RESULTS[@]}"; do
    [[ $first -eq 0 ]] && printf ','
    first=0
    IFS='|' read -r lvl name detail <<<"$r"
    printf '{"level":"%s","check":"%s","detail":"%s"}' "$lvl" "${name//\"/\\\"}" "${detail//\"/\\\"}"
  done
  printf ']}\n'
else
  printf '\n%s: %d pass, %d warn, %d fail — %s\n' "$FILE" "$PASS" "$WARN" "$FAIL" \
    "$([[ "$FAIL" -eq 0 ]] && echo 'SHIPABLE' || echo 'DO NOT DELIVER')"
  if [[ "$WARN" -gt 0 && "$FAIL" -eq 0 ]]; then
    printf 'Warnings must be named in DELIVERY.md before this ships.\n'
  fi
fi

[[ "$FAIL" -eq 0 ]] || exit 1
exit 0
