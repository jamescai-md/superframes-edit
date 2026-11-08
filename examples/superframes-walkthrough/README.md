# Walkthrough — the whole pipeline on one small film

A 9-second, three-scene film taken from an empty folder to verified delivery masters using nothing
but this repo's own scripts. It exists so every claim in the skills has a working artefact behind it.

The composition here **passes the real HyperFrames linter** (`lint.ok: true`, 0 errors). It is the
reference for the traps that cost the most time, all of which are described below.

## The film

```text
film/
  index.html                 the root composition: declares duration, size, scenes, audio
  compositions/intro.html    scene 1 — a title that resolves out of blur
  compositions/body.html     scene 2 — a masked line reveal
  compositions/outro.html    scene 3 — the URL, settled
  assets/bed.wav             a tone standing in for a music bed
```

Three scenes of 3 s each over a root `data-duration` of 9, 1920x1080 at 30 fps.

## Run it

```bash
# 0. what can this machine do?
bash skills/superframes-edit/scripts/superframes/doctor.sh

# 1-2. reference in, measurements out (any video works as a reference)
bash skills/superframes-acquire/scripts/superframes/provenance.sh init
bash skills/superframes-acquire/scripts/superframes/provenance.sh add \
  --file assets/ref/clip.mp4 --url "<URL>" --licence reference-only --use "style study"
bash skills/superframes-acquire/scripts/superframes/analyze.sh assets/ref/clip.mp4 --out analysis/

# 3-4. build and look at it
cd film
npx hyperframes check --json          # lint, layout, contrast, motion, craft, audio
npx hyperframes snapshot --at 1,4,7   # the frames are how you see the film
npx hyperframes render --quality draft -o ../out/draft.mp4

# 5. cut, normalise, export
cd ..
bash skills/superframes-cut/scripts/superframes/cut.sh normalise out/draft.mp4 out/mixed.mp4 -14 -1
bash skills/superframes-cut/scripts/superframes/cut.sh export out/mixed.mp4 out/web/film.mp4 web

# 6. prove it
bash skills/superframes-edit/scripts/superframes/verify.sh out/web/film.mp4 \
  --expect-duration 9 --expect-size 1920x1080 --expect-fps 30 \
  --audio --black --freeze --frames out/verify
```

## The four traps this example encodes

Every one of these was found by running the real linter, not by reading documentation.

### 1. The root composition must register its own timeline

```html
<script>
  window.__timelines = window.__timelines || {};
  window.__timelines["main"] = gsap.timeline({ paused: true });  // even when empty
</script>
```

Without it, `check` reports `missing_timeline_registry` for the root — while every scene is
perfectly fine. The root is a composition too.

### 2. A scene file's first element must be `<template>`

```html
<!-- compositions/intro.html -->
<template>
  <style>#root { position: absolute; inset: 0; }</style>
  <div id="root" data-composition-id="intro" data-width="1920" data-height="1080">…</div>
  <script>const tl = gsap.timeline({paused:true}); … window.__timelines["intro"] = tl;</script>
</template>
```

A trailing comment or a stray blank line before `<template>` makes the file fail
`missing_or_empty_sub_composition` with the message "no element with a data-composition-id
attribute", even though the attribute is clearly there. The parser resolves content from the
*first* template it meets.

### 3. Host id, scene root id and timeline key must be the same string

```html
<!-- index.html -->
<div id="intro" data-composition-id="intro" data-composition-src="compositions/intro.html" …></div>
```

| Mismatch | What you get |
| --- | --- |
| host id ≠ scene `data-composition-id` | a ~45 s wait per scene, then a static frame |
| timeline key ≠ scene `data-composition-id` | `timeline_id_mismatch`, and the scene never animates |
| scene root has no `data-composition-id` | `missing_or_empty_sub_composition` |

### 4. Use `fromTo`, not `from`, inside a scene

The host re-seeks a scene every time it shows. `from` records its start state once, so it drifts
on seek-back. Every tween in this example is `fromTo`.

## What this example is not

- It is not a design reference. The colours exist to make the contrast audit meaningful.
- It is not rendered here: this sandbox has no launchable Chrome, which is exactly what
  `doctor.sh` reports. `check` still runs its static audits and says `browserSkipped: true`.
- It is not the only way to build a film. `superframes-build` covers the Remotion track too; see
  `skills/superframes-build/references/remotion/`.

## Reading the check report

```bash
cat film/.hyperframes/artifacts/checks/*.json | python3 -m json.tool | head -40
```

| Field | Meaning |
| --- | --- |
| `lint` | the contract: timeline registration, ids, attributes, clip bounds |
| `layout` | overflow, overlap, safe-area violations |
| `contrast` | text against the sampled background, with a suggested colour |
| `motion` | dead frames, unmotivated moves |
| `craft` | authored-quality checks |
| `audio` | audio present, clips inside the duration |
| `runtime` | the browser pass; `browserSkipped: true` means no Chrome |
| `snapshots` | frames written for review |

The newest report is the one to read: reports are UUID-named, so sort by modification time, not by
name.
