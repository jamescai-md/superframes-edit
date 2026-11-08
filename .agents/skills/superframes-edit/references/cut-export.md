# Stage 5 — Cut, mix, export

FFmpeg is the stage where a good film becomes a broken file. Everything below is written against real failure modes, and `scripts/superframes/cut.sh` implements each one so you do not retype the flags.

## The two kinds of cut

Choosing wrong is the single most common FFmpeg mistake.

| | Stream copy | Re-encode |
| --- | --- | --- |
| Speed | instant | slower, scales with length and preset |
| Quality | lossless | one generation of loss |
| Precision | snaps to the previous keyframe | frame exact |
| Use when | rough assembly, extracting large sections, delivery mux | anything a viewer will judge |

```bash
# frame-exact (re-encode); -ss before -i seeks fast, then decodes to the exact frame
ffmpeg -ss 12.4 -i in.mp4 -t 3.2 -c:v libx264 -preset medium -crf 18 \
  -pix_fmt yuv420p -fps_mode cfr -c:a aac -b:a 192k -ar 48000 -movflags +faststart out.mp4

# lossless but keyframe-aligned (stream copy, no re-encode)
ffmpeg -ss 12.4 -i in.mp4 -t 3.2 -map 0 -c copy -avoid_negative_ts make_zero out.mp4
```

If a stream-copied cut starts a visible moment late or shows a frozen frame, that is keyframe drift, not a bug. Re-encode.

`-fps_mode cfr` (FFmpeg 5.1+) replaced `-vsync cfr`. On older builds the flag is `-vsync cfr`; a filtergraph-rate approach (`fps=30`) works everywhere. Check what the machine has with `scripts/superframes/doctor.sh`.

## Joining clips

Three methods, in order of safety:

```bash
# 1. Identical streams (same codec, size, fps, timebase): demuxer, instant, lossless
printf "file '%s'\n" clip1.mp4 clip2.mp4 > list.txt
ffmpeg -f concat -safe 0 -i list.txt -c copy joined.mp4

# 2. Anything else: the concat filter, which normalises as it joins
bash scripts/superframes/cut.sh concat joined.mp4 clip1.mp4 clip2.mp4 clip3.mp4

# 3. Encode the parts to identical parameters first, then method 1
```

Method 2 is the default in this skill. It forces one size, fps, pixel format and audio layout, and it inserts silence for a segment with no audio instead of desyncing the rest. The demuxer would silently drop or truncate those streams.

A visible black flash at a join is usually one frame of padding from the encoder, not a missing frame. Re-encode the join with the filter and the flash disappears.

## Audio: measure, then fix

Loudness is not volume. Integrated loudness (LUFS) is what the platform will normalise to; true peak (dBTP) is what will clip.

| Target | Use |
| --- | --- |
| -14 LUFS, -1 dBTP | streaming, YouTube, Spotify, general web |
| -16 LUFS, -1.5 dBTP | podcast, spoken-word |
| -18 to -20 LUFS | broadcast beds, dialogue-first content |
| -23 LUFS | EBU R128 broadcast delivery |

Two-pass, always. Measuring the source and applying the measurement is accurate; single-pass `loudnorm` adapts while it plays and pumps.

```bash
# pass 1: measure
ffmpeg -i in.mp4 -map 0:a:0 -af "loudnorm=I=-14:TP=-1:LRA=11:print_format=json" -f null -
# pass 2: apply the printed values (cut.sh normalise does this for you)
ffmpeg -i in.mp4 -c:v copy -af "loudnorm=I=-14:TP=-1:LRA=11:measured_I=…:measured_LRA=…:measured_TP=…:measured_thresh=…:offset=…:linear=true" \
  -ar 48000 -c:a aac -b:a 256k -shortest -t <original_duration> out.mp4
```

Two traps, both real:

- **Re-encoding audio alone can lengthen the file.** A 6.000 s clip can come out 6.100 s. Pass `-shortest` and an explicit `-t` equal to the original duration.
- **Normalise after you concatenate, not before.** Normalising each clip to -14 LUFS and then joining gives loudness that is worse than the original. Assemble first, measure once, apply once.

Ducking for a voiceover over music:

```bash
ffmpeg -i voice.wav -stream_loop -1 -i music.wav -filter_complex "\
[0:a]aresample=48000,aformat=channel_layouts=stereo,asplit=2[vo][key];\
[1:a]aresample=48000,aformat=channel_layouts=stereo,volume=-18dB[bed];\
[bed][key]sidechaincompress=threshold=0.03:ratio=8:attack=20:release=400[ducked];\
[vo][ducked]amix=inputs=2:duration=first:normalize=0[a]" -map "[a]" mix.m4a
```

`sidechaincompress` is what makes a mix sound mixed: the bed steps back while speech happens and returns on its own. `normalize=0` in `amix` prevents FFmpeg from halving both signals.

## Captions and subtitles

| Need | Do |
| --- | --- |
| Burned-in captions a viewer cannot turn off | `subtitles=` filter (needs libass; check `ffmpeg -filters`) |
| A sidecar file for a platform | ship the `.srt` unchanged, no burn |
| Styled captions matching the film | `force_style`, or author an `.ass` file |
| Captions generated from speech | transcribe first (`../media-use`), then shift, then burn |

```bash
ffmpeg -i in.mp4 -vf "subtitles='subs.srt':force_style='FontName=Inter,Fontsize=20,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,Outline=2,MarginV=64,Alignment=2'" \
  -c:v libx264 -crf 18 -c:a copy out.mp4
```

Colours in `force_style` are `&HAABBGGRR` — BGR order, easy to get backwards. Escape `:` in the path as `\:` and `'` as `\'`, or the filtergraph breaks.

A constant offset in burned captions means the problem is upstream: shift the subtitle timings, do not compensate with the filter.

`drawtext` is not always compiled in. If it errors with "Filter not found", the build lacks libfreetype, and `subtitles` with libass is the portable path for on-screen text.

## Speed

```bash
# 2x, both streams, pitch preserved
ffmpeg -i in.mp4 -filter_complex "[0:v]setpts=PTS/2[v];[0:a]atempo=2[a]" -map "[v]" -map "[a]" out.mp4
```

`atempo` spans 0.5–2.0 per instance in older builds (newer builds allow wider). For 0.3x or 4x, chain instances: `atempo=0.5,atempo=0.6` for 0.3x. Pitch is preserved by `atempo`, which is what you want for a voice; use `asetrate` deliberately if you want the chipmunk effect.

Changing speed changes duration. Re-derive every caption offset, every cut and the declared total from the new duration.

## Framing one master into several aspects

```bash
# 16:9 master to 9:16 without letterboxing: scale up, then centre-crop
ffmpeg -i master.mp4 -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1" ...
```

Centre-cropping a 16:9 master to 9:16 cuts off both sides — a subject at the edge of frame disappears. Two honest options: build the vertical edition in the authoring tool with its own layout, or reframe with a tracked crop. A blind centre crop is the most common "why did my video lose the product" bug in social delivery.

## Colour

Videos are judged on colour, and colour is where silent metadata damage happens.

```bash
# tag explicitly on every delivery encode
-color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv
```

| Symptom | Cause | Fix |
| --- | --- | --- |
| Washed out, milky | full-range RGB presented as limited | tag `-color_range tv`, or convert with `scale=…:in_range=full:out_range=tv` |
| Crushed blacks, blown highlights | limited presented as full | tag `-color_range pc`, or convert the other way |
| Green or magenta cast | primaries mismatch (e.g. bt709 content tagged bt470bg) | set primaries/matrix on export |
| Banding in gradients | 8-bit encode of a smooth ramp | add a light dither, or deliver 10-bit where the platform accepts it |

If the source is HDR (PQ or HLG), do not drop it into an SDR timeline without a tone-map. `zscale` plus `tonemap` is the minimum:

```bash
-vf "zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p"
```

## Containers and codecs for delivery

| Destination | Video | Audio | Container |
| --- | --- | --- | --- |
| Web `<video>` | H.264 High, yuv420p, 8–16 Mbps at 1080p | AAC-LC 192–320k, 48 kHz | MP4, `+faststart` |
| YouTube / Vimeo upload | H.264 High CRF 16–18, or ProRes for a festival | AAC 320k or PCM | MP4 / MOV |
| Instagram, TikTok, Reels | H.264 High, 1080x1920, CRF 20–22 | AAC 192k | MP4 |
| Broadcast | ProRes 422 HQ or XDCAM | PCM 48k | MOV / MXF |
| Archival master | ProRes 422 HQ, or FFV1 in MKV | PCM 48k 24-bit | MOV / MKV |
| Alpha / compositing | ProRes 4444, or VP9 `yuva420p`, or WebM `yuva420p` | PCM | MOV / WebM |
| Animation with flat colour | H.264 at CRF 14–16, or AV1 | AAC | MP4 |

Always `+faststart` for web MP4: it moves the index to the front so playback starts before the whole file arrives.

`scripts/superframes/cut.sh export` implements `master`, `web`, `social`, `vertical` and `square` presets with these parameters already set.

## The assembly order that avoids rework

1. **Conform** every source: one fps, one audio layout (`cut.sh conform`).
2. **Cut** each piece (`trim`, or the authoring tool's own timeline).
3. **Join** (`concat`).
4. **Mix** audio, add the voice, duck the bed (`mix`).
5. **Normalise** once, at the end of the audio chain (`normalise`).
6. **Burn** captions if they are burned.
7. **Export** per destination, tagged.
8. **Verify** every output (`references/verify.md`).

Doing 5 before 3 is the classic rework loop. Doing 7 before 8 is how a broken file reaches a client.

## Exit condition

- The assembled file exists at the spec's duration, fps and dimensions.
- Loudness is at the stated target, true peak under the ceiling, measured not guessed.
- Every export is explicitly colour-tagged.
- Each export has been through `verify.sh` with no FAIL.
