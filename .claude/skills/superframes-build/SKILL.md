---
name: superframes-build
description: Build a video as code. HTML/CSS/GSAP compositions rendered frame by frame with HyperFrames, or React/TSX compositions with Remotion — the render contract, project structure, registry blocks, cross-track moves, and the fix for each engine's known gap.
---

**Usage beacon:** run `npx hyperframes events --skill=superframes-build` once as this skill starts. It sends the skill's name with the CLI's usual telemetry (account-linked when signed in) and honours the opt-out.

# SuperFrames Build

Two authoring tracks. Pick by what exists and what the work needs, then follow that track's contract exactly — a contract violation renders a subtly broken file, not an error.

Stage reference: `../superframes-edit/references/build.md`. Motion rules: `../superframes-edit/references/motion.md`.

## Which track

| Situation | Track | Read first |
| --- | --- | --- |
| New project, design-led, no React needed | **HyperFrames** (default) | `../hyperframes/SKILL.md` |
| Existing Remotion or React project | **Remotion** — never rewrite it to switch tools | `references/remotion/remotion-best-practices/SKILL.md` |
| Needs a React-only library (charts, three, Rive, maps) | Remotion, or render an intermediate and composite | `references/remotion/remotion-multimedia/SKILL.md` |
| Needs a named visual (transition, title, chart, map, 3D) | HyperFrames + registry | `../hyperframes-registry/SKILL.md` |
| Must stay editable by a designer in a browser | HyperFrames | `../hyperframes-cli/SKILL.md` |
| Must ship inside a web app | Remotion (`@remotion/player`) | `references/remotion/remotion-saas/SKILL.md` |

## HyperFrames: the contract

Read `../hyperframes/SKILL.md` before writing markup; it holds the full contract and the reference index. The clauses that break renders when missed:

1. `index.html` is the root: declares duration, dimensions and variables, mounts one scene per file in `compositions/`.
2. Every timed element has `class="clip"`, `data-start`, `data-duration`, and lands its end state just before it ends.
3. Each composition builds one **paused** timeline and registers it after its tweens: `window.__timelines["<data-composition-id>"] = tl`.
4. No `Date.now()`, unseeded randomness, network, timers, or `repeat: -1`. Everything visible is a function of timeline time.
5. Never tween `display`, `visibility` or `autoAlpha` on a `.clip`; animate a child.
6. Never `play()`, `pause()` or seek media. A `<video>` with sound gets `data-has-audio="true"`, else `muted`.
7. Media and fonts live in `assets/`, referenced as `assets/…` with no leading slash, in sub-compositions too.
8. Grades, grain and vignettes on footage go through `npx hyperframes media-treatment`, never a CSS filter.

Then:

```bash
npx hyperframes init my-film --skip-skills
cd my-film
npx hyperframes check --json      # fix every error before snapshotting
npx hyperframes snapshot --at 1,4,8
npx hyperframes render --quality looks -o out.mp4
```

Command-by-command reference, including recovery and cloud options: `../hyperframes-cli/SKILL.md`. Ready-made blocks before you hand-build a named visual: `../hyperframes-registry/SKILL.md`. Music, SFX, images, voice, grades: `../media-use/SKILL.md`.

## Remotion: the contract

The Remotion corpus is vendored in this skill, so the React track needs no second install:
read `references/remotion/remotion-best-practices/SKILL.md`, then the sub-skill for the job
(`remotion-create`, `remotion-markup`, `remotion-captions`, `remotion-render`,
`remotion-multimedia`, `remotion-maps`, `remotion-interactivity`, `remotion-studio`).
`references/remotion/README.md` is the index.

```bash
npx create-video@latest --yes --blank --no-tailwind my-film
cd my-film && npm i
npx remotion studio             # --no-open when an agent owns the browser
npx remotion render <id> out/master.mp4
```

The clauses that matter for an agent working in someone's project:

- One `<Composition>` per independently editable unit, literal string `id`, props inline on the node.
- The parent owns timing: `<Sequence from durationInFrames>`, `<Track>`, or `<TransitionSeries>` (whose overlaps shorten the total).
- Media through `@remotion/media` (`<Video>`, `<Audio>`) so trims are `trimBefore`/`durationInFrames`, not re-encoded files.
- `staticFile()` for local assets; no remote URLs during a delivery render.
- Duration that depends on audio belongs in `calculateMetadata`.
- FFmpeg ships with Remotion: `npx remotion ffmpeg` needs no install. Use it when a machine has no FFmpeg, but still pass the delivery flags from `../superframes-cut/SKILL.md`.

Licensing is real: Remotion requires a paid company licence for teams above its free threshold. Disclose the choice in `DELIVERY.md`; do not let a person ship commercially on a track they are not licensed for.

## Mixing the two on purpose

| Need | Move |
| --- | --- |
| A React-only visual in an HTML film | render it in Remotion with `--codec=vp9 --pixel-format=yuva420p` or ProRes 4444, then composite it from `assets/` |
| An HTML scene in a React project | render the scene as an intermediate, or reproduce it as a component; never iframe a live server into a render |
| A Remotion project that should become HTML-native | `../remotion-to-hyperframes/SKILL.md` — it verifies frame by frame |
| A Remotion question about a specific API | `references/remotion/remotion-docs/SKILL.md`, then upstream docs when the snapshot disagrees |
| A film that must match a reference exactly | acquire and analyse first (`../superframes-acquire/SKILL.md`), then build in the reference's medium |

An intermediate is a pixel dependency: baked, in `assets/`, provenance recorded, verified against its source. Never ship a render that depends on another process being up.

## Gaps, and which track covers them

| Gap in one tool | Covered by |
| --- | --- |
| No media of its own (HyperFrames) | `../media-use` — catalog music, assets, voice, grades |
| No long-footage editing | `../superframes-cut` — segments, concat, J/L cuts |
| Some Remotion features need a company licence | HyperFrames track, or buy the licence and disclose |
| Silent font fallbacks | font audit before delivery (`../superframes-edit/references/verify.md`) |
| Neither normalises loudness | `../superframes-cut` normalise pass |
| Neither proves A/V sync | `../superframes-edit/references/verify.md` |
| A render can "succeed" and look wrong | frames inspection + SSIM/PSNR |

## Rules that are not preferences

- Read the track's contract before writing markup. Both engines fail silently, not loudly.
- Never rewrite a working Remotion project into HyperFrames to make your job easier; migrate only when asked.
- Never leave a remote asset in a delivery render.
- Never skip `check` (HyperFrames) or a full-length render pass (Remotion) before calling a scene done.
- Never hand-build a named visual without searching the registry first.

## Where to read next

| Need | Read |
| --- | --- |
| The vendored Remotion corpus, indexed | `references/remotion/README.md` |
| The full pipeline and stage order | `../superframes-edit/SKILL.md` |
| Motion, easing, transition craft | `../superframes-edit/references/motion.md` |
| Cut, mix and export the result | `../superframes-cut/SKILL.md` |
| Verify the render | `../superframes-edit/references/verify.md` |
