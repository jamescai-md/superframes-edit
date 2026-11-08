# Stage 2 — Analyse a reference

This stage exists because "make it like this video" is the most common request and the least reproducible one. The output is `ANALYSIS.md`: numbers and timecodes, not impressions.

## Measure before you look closely

```bash
bash scripts/superframes/analyze.sh <reference.mp4> --out analysis/
```

It writes: `probe.json` (streams, fps, colour tags), `sheet.png` (contact sheet), `scenes.txt` (cut timestamps), `audio.json` (loudness and peaks), `palette.txt` (dominant colours). Then work through the sections below using those artefacts.

## Shot list

Detect cuts, then correct them by eye. Scene detection over-triggers on flashes and fast motion.

```bash
ffmpeg -hide_banner -i ref.mp4 -vf "select='gt(scene,0.30)',showinfo" -f null - 2>&1 \
  | grep -oE "pts_time:[0-9.]+" | cut -d: -f2
```

Thresholds: `0.4` finds hard cuts; `0.2` finds soft cuts and dissolves but adds false positives; `0.1` is noise. For a music video, cross-check cuts against the beat grid.

Fill the shot table. A shot with no entry is a shot you will get wrong.

| # | In | Out | Length | Shot size | Camera | Subject | Transition in | Speed |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0.00 | 2.40 | 2.40 | wide | static | skyline | fade from black | 1.0 |

## Motion read

For each shot, name the motion in production language, because that maps to an implementable value:

| Observed | Name | Implementation |
| --- | --- | --- |
| Everything grows from centre | push-in / punch | `scale 1.0 → 1.06`, ease-out |
| Text rises into place | reveal-up with mask | mask 0 → 100%, 2 px feather, 320 ms |
| Elements slide in from the edge | offscreen entry | translate 40 px → 0 plus 200 ms opacity |
| Background crawls behind a static product | parallax | 0.08 scale factor per depth layer |
| Colours pop between shots | hard cut on beat | cut on the beat grid, no transition |

Also record: average shot length, cut rate over time (does it accelerate?), and whether the film uses a consistent optical grid (recurring distance from frame edge).

## Palette and grade

```bash
ffmpeg -hide_banner -i ref.mp4 -vf "fps=1,scale=160:-1,palettegen=max_colors=12:stats_mode=full" -y palette.png
ffmpeg -hide_banner -i ref.mp4 -vf "fps=1,scale=160:-1,palettegen=max_colors=12:stats_mode=full" -f rawvideo -pix_fmt rgb24 - 2>/dev/null | xxd -ps | head
```

Better, read the pixels straight out of a palette PNG with Python (`scripts/superframes/motiontools.py palette`). Record six hex values with roles: background, primary, accent, text, shadow, highlight. Name the grade: neutral, teal-orange, bleached, monochrome, warm-print, cyan-tech.

Check the colour tags, because they explain "why does my copy look washed out":

```bash
ffprobe -v error -select_streams v:0 \
  -show_entries stream=color_space,color_transfer,color_primaries,color_range -of default=nw=1 ref.mp4
```

If the reference is `bt709/tv` and your render is untagged full-range, match it explicitly on export (`-color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv`).

## Type and layout

- Measure the cap height of one headline in pixels, then derive the type scale from it.
- Note the margin grid: the distance from frame edge to the first element, in percent of width.
- Note safe zones in use: a 4:5 edition of a 16:9 master usually has its text inside 80% width.
- Identify the family by shape, not vibes: grotesque, transitional serif, mono, humanist. If the exact font is unlicensed, pick the closest open equivalent and record the substitution.

## Audio read

```bash
ffmpeg -hide_banner -i ref.mp4 -map 0:a -af loudnorm=print_format=json -f null - 2>&1 | tail -20
ffmpeg -hide_banner -i ref.mp4 -map 0:a -af silencedetect=noise=-35dB:d=0.35 -f null - 2>&1 | grep silence_
```

Record: integrated loudness, true peak, tempo, whether cuts land on the beat, whether the voice sits above or under the music, and the silence map (useful for a voiceover cut).

## What to write down

`ANALYSIS.md` must let a stranger rebuild the look without watching the reference:

1. Duration, fps, dimensions, colour tags.
2. Shot table with timecodes.
3. Motion vocabulary with numbers.
4. Six-colour palette with roles, plus the grade name.
5. Type scale, margins, safe zones.
6. Audio measurements and sync observations.
7. **What to copy and what to change.** Copying a competitor's film frame for frame is a legal and ethical problem. Copy the *system* — pacing, palette structure, motion grammar — and change the content, the type and the specifics. State the difference explicitly in `DELIVERY.md`.

## Exit condition

`ANALYSIS.md` plus the `analysis/` artefacts exist, and every number in them came from the reference rather than from memory. Mark anything estimated as **Assumption**.
