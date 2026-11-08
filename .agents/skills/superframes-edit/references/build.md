# Stage 3 — Build

Two authoring tracks, one spec. Pick the track from the project that exists and the ecosystem the work needs, not from preference.

## Which track

| Situation | Track |
| --- | --- |
| New project, design-heavy, HTML/CSS skills already present, agent will write markup | **HyperFrames** (default) |
| Existing Remotion/React/TSX project | **Remotion** — do not rewrite it |
| Needs an npm React library (charts, three.js wrappers, Rive, Mapbox React) | Remotion, or a rendered intermediate composited into HyperFrames |
| Needs 450 ready-made motion blocks (transitions, titles, charts, maps) | HyperFrames (`../hyperframes-registry`) |
| Must be editable by a designer in a browser without an npm install | HyperFrames |
| Must ship as a React component or in a web app | Remotion (`@remotion/player`) |
| Batch render hundreds of variants from rows of data | Either; HyperFrames `render --batch` or Remotion `--props` |
| Long-form footage assembly with cuts | Neither is the tool. Stage 5 (`references/cut-export.md`) then bring the timeline in |

Default to HyperFrames for anything new: it renders frame-accurately from a paused timeline, the project is plain files a person can edit, and the merged registry covers most named visuals. Switch to Remotion when React is the point.

## Track A — HyperFrames

The authoring contract lives in `../hyperframes/SKILL.md`; read it before writing markup, then `../hyperframes/references/format.md` for the exact attributes. The short version, because violating any of these produces a subtly broken render:

- `index.html` is the root composition: it declares the duration, dimensions and variables, and mounts one scene per sub-composition from `compositions/`.
- Every timed element carries `class="clip"`, `data-start`, `data-duration`, and lands its end state just before it ends.
- Each composition builds one paused GSAP timeline and registers it: `window.__timelines["<id>"] = tl`.
- Nothing visible depends on wall-clock time, unseeded randomness, network, or `repeat: -1`.
- Media and fonts live in `assets/`, referenced as `assets/...` with no leading slash.
- Never `play()`/seek media; a `<video>` with sound gets `data-has-audio="true"`, otherwise it is `muted`.

Scaffold and check:

```bash
npx hyperframes init my-film --skip-skills
cd my-film && npx hyperframes check --json     # gate before every snapshot
npx hyperframes snapshot --at 1,4,8            # look at the frames
```

Minimum viable scene file, correct in shape:

```html
<template id="scene-intro">
  <style>
    #root { position: absolute; inset: 0; background: #0b0b0c; }
    .headline { position: absolute; left: 8%; bottom: 12%; color: #f4f1ea;
                font: 700 96px/1.02 "Inter", sans-serif; letter-spacing: -0.02em; }
  </style>
  <div id="root">
    <h1 class="headline clip" id="h1" data-start="0.2" data-duration="3.4">Export in one press</h1>
  </div>
  <script>
    window.__timelines = window.__timelines || {};
    const tl = gsap.timeline({ paused: true });
    tl.from("#h1", { yPercent: 30, opacity: 0, duration: 0.5, ease: "power3.out" }, 0.2);
    tl.to("#h1", { yPercent: -6, opacity: 0, duration: 0.3, ease: "power2.in" }, 3.3);
    window.__timelines["scene-intro"] = tl;
  </script>
</template>
```

Copy whole working projects instead of inventing structure: `examples/` in this repo holds complete films, and `../hyperframes-registry` has ready blocks.

## Track B — Remotion

```bash
npx create-video@latest --yes --blank --no-tailwind my-film
cd my-film && npm i
npx remotion studio            # or --no-open when an agent owns the browser
npx remotion render <id> out/master.mp4
```

Rules that keep a Remotion project editable and agent-safe:

- One `<Composition>` per independently editable unit, with a literal string `id` and its props inline on the node.
- Scenes are components; the parent owns timing. Use `<Sequence from durationInFrames>` or `<Track>` for independent start times, `<TransitionSeries>` when scenes must stay adjacent as their durations change. Transition overlaps shorten the total duration — account for them.
- Media from `@remotion/media` (`<Video>`, `<Audio>`), never raw `<video>`: `trimBefore`/`durationInFrames` give non-destructive trims.
- `staticFile()` for local assets under `public/`; remote URLs are allowed but never during a delivery render.
- Duration that depends on audio length belongs in `calculateMetadata`, not a hardcoded constant.

```tsx
import {Composition, Sequence, staticFile} from "remotion";
import {Video, Audio} from "@remotion/media";
import {Title} from "./scenes/Title";

export const Root = () => (
  <Composition id="Launch" component={Launch} durationInFrames={540} fps={30} width={1920} height={1080} />
);

const Launch = () => (
  <>
    <Sequence from={0} durationInFrames={90} name="Title"><Title text="Export in one press" /></Sequence>
    <Video src={staticFile("footage/hero.mp4")} trimBefore={45} durationInFrames={240} />
    <Audio src={staticFile("audio/bed.wav")} volume={0.4} />
  </>
);
```

FFmpeg ships with Remotion: `npx remotion ffmpeg` and `npx remotion ffprobe` need no separate install, which is the cheapest way to get FFmpeg on a machine that has none. Everything in stage 5 still applies — Remotion's own `-c:v h264` defaults are a starting point, not a delivery spec.

## Crossing tracks deliberately

A combined pipeline can do what neither tool does well alone:

| Need | Move |
| --- | --- |
| A React-only visual inside an HTML film | Render that sequence in Remotion with a transparent codec: `--codec=vp9 --pixel-format=yuva420p`, or ProRes 4444 (`--codec=prores --prores-profile=4444`), then place it in `assets/` and composite in HyperFrames |
| An HTML/CSS scene inside a React project | Render it as an intermediate from HyperFrames, or reproduce it as a component; do not iframe a live server into a render |
| Existing Remotion project that must become HTML-native | `../remotion-to-hyperframes` migrates it and verifies frame by frame |
| A video that must match a reference exactly | Acquire (1), analyse (2), build in the track that matches the reference's medium (3) |

The rule for mixing: an intermediate is a *pixel* dependency. It is baked, it is in `assets/`, it is verified against its source, and its provenance is recorded. Never ship a render that depends on another server being up.

## Known gaps, and what covers them

This is the reason the tracks are merged. Each entry is a real limitation of a single tool and the counterpart that fills it.

| Gap | In that tool alone | Covered here by |
| --- | --- | --- |
| No visual assets or music | HyperFrames ships no media | `../media-use`: catalog music, SFX, images, logos, voice, grades |
| No footage cutting | HyperFrames composes, it does not edit a long recording | Stage 5: FFmpeg segments, concat, J/L cuts |
| No licence awareness | yt-dlp will download anything | Stage 1 licence classes plus `provenance.sh` |
| Subscription for some features | Remotion needs a company licence above 3 employees | HyperFrames track, or buy the licence; disclose the choice |
| Heavy render footprint | Remotion needs Chrome plus a bundler per render | HyperFrames render, or a prebuilt bundle and a warm Studio |
| Silent font fallbacks | Both render with whatever font resolves | Font audit in stage 6; bundled fonts or `@font-face` |
| Noisy audio by default | Neither normalises loudness | Stage 5 loudness pass to a stated target |
| No A/V sync proof | Both assume sync | Stage 6 `verify.sh --audio` measures it |
| Format handling by hand | Both leave containers, ranges and colour tags to you | Stage 5 export matrix, explicit tags |
| No frame verification | A render can "succeed" and look wrong | Stage 6 contact sheets, SSIM/PSNR against a reference |

## Exit condition

- A project exists that renders at the spec's dimensions, fps and duration.
- One scene per sub-composition or one component per independently editable unit.
- `npx hyperframes check --json` is clean, or the Remotion project renders one full frame at t=0 and t=end without error.
- No remote dependency during a render; every asset is local with provenance.
- The build command is written into `README.md` so the next person can reproduce it.
