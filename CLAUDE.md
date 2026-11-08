# SuperFrames Edit

One skill for the whole AI video pipeline. A fork of HeyGen's HyperFrames that merges Remotion,
FFmpeg and yt-dlp into a single contract: build the video as code, animate it, cut and mix it,
download and measure references, verify it frame by frame, and export delivery masters.

## Skills

Thirteen published skills. Install them before writing a composition — they encode framework
specifics that generic documentation does not cover. The four `superframes-*` skills are the entry
points; the rest are the HyperFrames set they coordinate.

```bash
claude plugin marketplace add jamescai-md/superframes-edit
claude plugin install superframes-edit@superframes-edit
claude plugin details superframes-edit                     # confirm the inventory
```

Reload the session (or `/reload-plugins`) after installing or updating. Skills are namespaced:
`/superframes-edit:superframes-edit`. To let the marketplace auto-update, run `/plugin` in Claude
Code's terminal UI, open **Marketplaces**, select **superframes-edit**, and enable auto-update.

Other agents: `npx skills add jamescai-md/superframes-edit`, or
`gemini extensions install https://github.com/jamescai-md/superframes-edit`.

- `superframes-edit` — **read first** for any video request. Holds the contract, the seven stages,
  the routing table and the failure playbook.
- `superframes-build` — build as code: HyperFrames (HTML/CSS/GSAP) or Remotion (React/TSX), with
  the Remotion corpus vendored in `skills/superframes-build/references/remotion/`.
- `superframes-cut` — the FFmpeg stage as tested subcommands: trim, concat, mix, normalise, speed,
  captions, delivery encodes, plus `references/ffmpeg-notes.md`.
- `superframes-acquire` — yt-dlp downloads, access walls, `provenance.sh`, `analyze.sh`, plus
  `references/ytdlp-notes.md`.
- `hyperframes` — the authoring contract and the film, motion, look, captions and story references.
- `hyperframes-cli` — the CLI by job, and recovery from build or render failures.
- `hyperframes-registry` — about 450 ready-made blocks and components, installed as editable source.
- `media-use` — music, SFX, images, logos, voice, avatars, transcripts, grades, audio mixing.
- `slideshow` — a navigable deck, not an MP4.
- `remotion-to-hyperframes` — migrate Remotion, Motion Canvas, Lottie or Three.js into HTML.
- `reverse-any-video` — rebuild any video file as an editable project.
- `style-sampling` — new episodes in one of five proven styles.
- `figma` — rendered assets, brand tokens, components and storyboard frames as reconstructed motion.

Make any video by asking for it. The request routes through `superframes-edit`; do not start a
stage without reading its reference.

## The pipeline

Seven stages with exit conditions: intake → acquire → analyse → build → motion → cut and mix →
verify → deliver. The stage table with what each one requires and what it must produce lives in
`skills/superframes-edit/SKILL.md`.

## Before the first command on a new machine

```bash
bash skills/superframes-edit/scripts/superframes/doctor.sh
```

Required: Node 22+, `ffmpeg`, `ffprobe`. Optional: `yt-dlp`, Chrome, a HeyGen sign-in. A missing
required track blocks the job; a missing optional one routes around it.

## Build and test this repository

```bash
bun install     # Install dependencies (NOT pnpm — do not create pnpm-lock.yaml)
bun run build   # Build all packages
bun run test    # Run all tests
```

Packages load each other through their `exports`. Under Node, core, parsers, lint and studio-server
resolve to `dist/`, and player always loads its built bundle. Run `bun run build` once in a fresh
worktree, before any package's tests or typecheck. After editing a package that another package
imports, run that package's `build` again before the dependent package's tests. Core's
`src/generated/` is git-ignored build output: if you see
`Cannot find module '../generated/runtime-inline'`, run `bun run build:hyperframes-runtime`.

One file: `bun run --cwd packages/<pkg> test <path>`. Each package's `test` script picks its runner
(vitest in most, `bun test` in aws-lambda and gcp-cloud-run). Producer is the exception: a file that
imports `bun:test` runs with `bun test <file>`, any other with `bunx vitest run <file>`. Root
`scripts/*.test.mjs` run through `bun run test:scripts`, which is an explicit list in `package.json`.
CI's test-reachability check fails any test file that no runner reaches.

### The skills gate

Any change to a skill must pass all three, and so must a pull request:

```bash
node scripts/superframes-verify/verify-skills.mjs   # frontmatter, names, descriptions, paths, scripts, mirror
node scripts/superframes-verify/check-clean.mjs     # no credentials, env files or build output
node scripts/superframes-verify/gen-manifest.mjs    # refresh skills-manifest.json (--check in CI)
```

`verify-skills.mjs` enforces the rules that matter: one malformed `SKILL.md` aborts `skills add` for
the whole repo, a description over 320 B is installed on every turn forever, a backtick span
containing `!` or `>word` makes Claude Code refuse to load the skill, and `.claude/skills` and
`.agents/skills` must mirror byte for byte.

Per-skill size budgets live in `scripts/check-core-skills.mjs`, which also checks that every
`npx hyperframes <command>` a core skill names is actually registered by the CLI.

### Linting and formatting

Uses **oxlint** and **oxfmt** (not eslint, not prettier, not biome).

```bash
node_modules/.bin/oxlint <files>        # Lint
node_modules/.bin/oxfmt <files>         # Format
```

## Skill catalogue maintenance

When adding, renaming or substantially repurposing a skill, update every discoverability surface in
lockstep, because an out-of-date entry silently kills discovery:

1. The skill list in this file, the list in `CLAUDE.md`, and the tables in `README.md` and
   `skills/superframes-edit/SKILL.md`.
2. The size budget in `scripts/check-core-skills.mjs`, if the skill is named there.
3. `skills-manifest.json`, via `node scripts/superframes-verify/gen-manifest.mjs`.
4. The mirrors: `cp -r skills/<name> .claude/skills/<name>` and `.agents/skills/<name>`.

## Provenance discipline

This repository merges four upstream projects. Anything added must be credited in
`THIRD_PARTY_NOTICES.md` with its licence. Do not vendor code under a licence that forbids it, and
do not describe a derived skill as original work.
