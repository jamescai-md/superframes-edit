# FFmpeg field notes

A working digest of the FFmpeg surface this skill depends on. Not a mirror of the manual —
just the parts that decide whether a delivered file is right, plus the exact syntax that is
easy to get wrong.

## Invocation shape

```
ffmpeg [global] [input options] -i INPUT [output options] OUTPUT
```

Options bind to the *next* input or output, not the line. `-ss` before `-i` is an input option
(fast seek); after `-i` it is an output option (decode then discard). This one distinction
explains most "my trim is inaccurate" reports.

| Global | Use |
| --- | --- |
| `-hide_banner` | quieter logs |
| `-nostdin` | never wait on stdin (required in scripts and agents) |
| `-y` | overwrite |
| `-loglevel error` | errors only |
| `-stats` / `-nostats` | progress on/off |

## Stream selection and mapping

| Need | Flag |
| --- | --- |
| Default stream of each type | `-map 0` for all, or nothing |
| First video only | `-map 0:v:0` |
| All audio tracks | `-map 0:a` |
| Drop video | `-vn` |
| Drop audio | `-an` |
| From a filtergraph | `-map "[vout]" -map "[aout]"` |
| Burn in subtitles from a stream | `-map 0:s:0` plus the `subtitles` filter, or `-map 0:v -map 0:a` |

## Codecs and quality

| Codec | Encoder | Quality control | Good for |
| --- | --- | --- | --- |
| H.264 | `libx264` | `-crf 16–23` | everything web; the safe default |
| H.265 | `libx265` | `-crf 18–26` | half the bitrate, weaker browser support |
| AV1 | `libsvtav1` | `-crf 24–35`, `-preset 6–8` | modern platforms, slow encode |
| VP9 | `libvpx-vp9` | `-crf 24–36`, `-b:v 0` | WebM, alpha (`yuva420p`) |
| ProRes 422 HQ | `prores_ks` | `-profile:v 3` | editing masters, broadcast |
| ProRes 4444 | `prores_ks` | `-profile:v 4 -pix_fmt yuva444p10le` | alpha for compositing |
| FFV1 | `ffv1` | lossless | archival |
| AAC | `aac` | `-b:a 192k–320k` | delivery audio |
| Opus | `libopus` | `-b:a 128k` | WebM speech |
| PCM | `pcm_s16le` / `pcm_s24le` | none | intermediates, masters |

CRF is quality-targeted and bitrate-variable; `-b:v` is bitrate-targeted and quality-variable.
For delivery, CRF plus `-maxrate`/`-bufsize` when a platform caps uploads:

```bash
-c:v libx264 -crf 20 -maxrate 12M -bufsize 24M
```

`-preset` trades time for size: `ultrafast` … `veryslow`. `slow` is the usual delivery choice;
`medium` for iteration.

Add `-tune film|animation|grain` only when the content clearly matches; the wrong tune hurts.
`-profile:v high -level 4.1` covers 1080p30 playback everywhere; `4.2` for 1080p60.

## Frame rate

| Need | Flag |
| --- | --- |
| Constant rate (5.1+) | `-fps_mode cfr` |
| Variable rate (5.1+) | `-fps_mode vfr` |
| Constant rate, older builds | `-vsync cfr` |
| Portable, always works | filtergraph `fps=30` |
| Duplicate/drop frames to hit a rate | `-vf fps=30` |
| Slow motion without dropping frames | `setpts=PTS/2` on video plus `atempo` on audio |

A variable-frame-rate source (phone recordings, screen captures, some downloads) is the root
cause of drift and desync. Conform first; do not attempt to fix it downstream.

## Filters that carry weight

| Filter | Use | Note |
| --- | --- | --- |
| `scale=W:H:flags=lanczos` | resize | `force_original_aspect_ratio=decrease` plus `pad` to letterbox |
| `crop=W:H:X:Y` | reframe | `crop=1080:1920` after an upscale is a cover-crop |
| `setsar=1` | square pixels | do it after every scale or crop |
| `fps=N` | rate conform | first in the chain, before expensive filters |
| `xfade` | two-clip transition | needs both clips at identical size, fps, SAR, pix_fmt and format |
| `acrossfade=d=N:c1=tri:c2=tri` | audio crossfade | match the visual crossfade duration |
| `tpad=start_duration=N` | pad the head | for a lead-in before a title |
| `tile=4x3` | contact sheet | `-frames:v 1` after it |
| `palettegen` / `paletteuse` | GIF from video | `palettegen=max_colors=256:stats_mode=full` |
| `loudnorm` | EBU R128 | two-pass; see below |
| `silencedetect=n=-35dB:d=0.35` | silence map | threshold tuned to the source |
| `blackdetect=d=0.5:pix_th=0.10` | dropped segments | any hit is worth a look |
| `freezedetect=n=-60dB:d=2` | stuck renders | long hits mean a stalled capture |
| `ssim` / `psnr` | quality against a reference | `[main][ref]ssim`; read `All:` |
| `subtitles=` / `ass` | burn captions | needs libass; escape `:` and `'` in the path |
| `drawtext` | on-screen text | needs libfreetype; often absent from static builds |
| `zscale` + `tonemap` | HDR to SDR | `tonemap=hable`, then `zscale=t=bt709:m=bt709:r=tv` |
| `eq=contrast=…:saturation=…` | a quick grade | prefer a LUT or a treatment pass for real work |
| `unsharp` / `gblur` | sharpness / blur | subtle values only; heavy use looks like a filter |
| `minterpolate` | frame interpolation | slow, ghosty on live action; not a safe default |
| `anullsrc=r=48000:cl=stereo` | silence for a missing track | keeps concat segments aligned |

`xfade` needs both inputs to share size, rate, SAR, pixel format *and* pixel format enum — the
last one is the usual cause of `Input link ... parameters do not match` even when everything
looks identical. Normalise both inputs with `scale,setsar,fps,format` first.

## Loudness, correctly

```bash
# pass 1 — measure
ffmpeg -nostdin -i in.mp4 -map 0:a:0 -af "loudnorm=I=-14:TP=-1:LRA=11:print_format=json" -f null -
# pass 2 — apply the measured values (linear keeps dynamics, avoids pumping)
ffmpeg -nostdin -i in.mp4 -c:v copy \
  -af "loudnorm=I=-14:TP=-1:LRA=11:measured_I=…:measured_LRA=…:measured_TP=…:measured_thresh=…:offset=…:linear=true" \
  -ar 48000 -c:a aac -b:a 256k -shortest out.mp4
```

`input_i` is integrated loudness; `input_tp` is true peak; `input_thresh` is the EBU R128 gate.
`linear=true` applies gain rather than dynamic processing — the right choice unless the source's
dynamic range genuinely needs compression.

Two hard-won details: an audio-only re-encode can lengthen the file (pass `-shortest` plus an
explicit `-t`), and normalising before concatenation produces a worse result than normalising once
afterwards.

Ducking a bed under speech:

```bash
-filter_complex "[0:a]aresample=48000,aformat=channel_layouts=stereo,asplit=2[vo][key];\
[1:a]aresample=48000,aformat=channel_layouts=stereo,volume=-18dB[bed];\
[bed][key]sidechaincompress=threshold=0.03:ratio=8:attack=20:release=400[ducked];\
[vo][ducked]amix=inputs=2:duration=first:dropout_transition=2:normalize=0[a]"
```

`normalize=0` stops `amix` from halving both inputs, which is why hand-rolled mixes sound quiet.

## Containers

| Container | Flags | Notes |
| --- | --- | --- |
| MP4 | `-movflags +faststart` | moves the index to the front; required for web playback |
| MP4, fragmented | `-movflags frag_keyframe+empty_moov` | streaming; larger overhead |
| MKV | — | tolerates anything; bad for browsers |
| WebM | `-c:v libvpx-vp9 -c:a libopus` | alpha needs `yuva420p` |
| MOV | — | ProRes and PCM homes |
| MXF | `-f mxf` | broadcast interchange |
| Image sequence | `-f image2 out-%05d.png` | frame-accurate intermediates |

## Colour, in one table

```bash
-color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv   # SDR video, limited
```

| Problem | Cause | Fix |
| --- | --- | --- |
| Milky, washed out | full-range presented as limited | tag `tv`, or `scale=…:in_range=full:out_range=tv` |
| Crushed blacks | limited presented as full | tag `pc` |
| Green or magenta cast | primaries mismatch | set primaries/matrix explicitly |
| Banding | 8-bit smooth gradient | dither, or deliver 10-bit |

If the source is HDR (PQ/HLG) and the destination is SDR, tone-map; do not just tag it SDR.

## Reading the log

| Line | Meaning |
| --- | --- |
| `Duration: 00:00:18.00, bitrate: 4210 kb/s` | real duration; compare to spec |
| `Stream #0:0(und): Video: h264, yuv420p, 1920x1080, 30 fps` | real codec, pixel format, size, rate |
| `[libx264] kb/s: 4210` | encoded bitrate |
| `frame= 540 fps= 42 q=-1.0 Lsize= …` | frames written, wall speed, output size |
| `Non-monotonous DTS in output stream` | timestamps were repaired; the source is suspect |
| `deprecated pixel format used, make sure you did set range correctly` | missing `-pix_fmt yuv420p` and range tags |
| `Conversion failed!` | read upward: the first error is the real one |
| `Output file is empty` | filters consumed everything, or a `-t 0` |

## Exit codes

`0` means FFmpeg finished. It does **not** mean the file is correct. Always `ffprobe` the output
and run the verification gate (`../superframes-edit/references/verify.md`).
