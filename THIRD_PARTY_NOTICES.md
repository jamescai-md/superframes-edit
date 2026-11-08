# Third-party notices and provenance

SuperFrames Edit is a fork of [heygen-com/hyperframes](https://github.com/heygen-com/hyperframes)
that merges four video-tool skills into one. This file records exactly what came from where, so
the licensing story is auditable rather than implied.

This repository as a whole is distributed under the **Apache License 2.0** (see `LICENSE`), the
licence of the upstream fork. Individual upstream projects keep their own licences, listed below.
Nothing here is endorsed by, or affiliated with, any upstream project.

## Merged video skills

### HyperFrames — the fork base

- **Source:** https://github.com/heygen-com/hyperframes
- **Licence:** Apache-2.0
- **What we kept:** the whole repository — renderer packages, CLI, block registry, examples, themes,
  the nine published skills (`hyperframes`, `hyperframes-cli`, `hyperframes-registry`, `media-use`,
  `figma`, `slideshow`, `remotion-to-hyperframes`, `reverse-any-video`, `style-sampling`), and the
  seven repo-internal motion skills.
- **What we removed:** the Docusaurus documentation site (`docs/` minus the generated schema), the
  internal planning notes (`plans/`, `updates/`), and the upstream CI workflows and release
  automation (npm publishing, cloud deployment, catalog publishing). None of it affects rendering.
- **What we changed:** repo identity and plugin manifests; four merged SuperFrames skills; a merged
  landing README; stricter skill verification; per-skill size budgets in `check-core-skills.mjs`.
- **Attribution:** the HyperFrames name and its documentation remain HeyGen's. This repo does not
  claim authorship of the renderer.

### Remotion — the React track

- **Source:** https://github.com/remotion-dev/remotion (`packages/skills/skills`)
- **Licence:** Remotion is **not** open source in the usual sense. The `remotion` npm package and
  its skills are published under the [Remotion License](https://github.com/remotion-dev/remotion/blob/main/LICENSE.md),
  which is free for individuals, non-profits and small companies, and requires a paid company
  licence above its stated employee threshold.
- **What we vendored:** the skill *documentation* — `SKILL.md` and topic markdown files for the
  thirteen Remotion skills — under `skills/superframes-build/references/remotion/`, so the React
  track works with no second install.
- **What we did not vendor:** Remotion source code, binaries, or any package. Using the React track
  still means installing Remotion from npm and complying with its licence.
- **Consequence, stated plainly:** if you use the Remotion track commercially at company scale, buy
  the licence. `superframes-build` requires that the choice be disclosed in `DELIVERY.md`.

### FFmpeg — the cut and export stage

- **Source:** https://github.com/FFmpeg/FFmpeg
- **Licence:** LGPL-2.1-or-later by default; GPL-2.0-or-later when built with GPL-only components
  (`--enable-gpl`, as most distribution builds are). FFmpeg is not distributed in this repository.
- **What we derived:** the command surface, the filter syntax, the failure modes and their fixes,
  captured in `skills/superframes-cut/references/ffmpeg-notes.md` and implemented as
  `skills/superframes-cut/scripts/superframes/cut.sh`.
- **What this repo ships:** only its own shell code, written against FFmpeg's documented interface.
  It invokes the `ffmpeg` binary the user already has.
- **Codec patents:** distributing H.264/H.265 encodes can carry patent obligations in some
  jurisdictions. That is between you and your codec licensor; this repository takes no position.

### yt-dlp — reference acquisition

- **Source:** https://github.com/yt-dlp/yt-dlp
- **Licence:** Unlicense (public domain dedication).
- **What we derived:** option semantics, format selectors, the access-wall playbook, captured in
  `skills/superframes-acquire/references/ytdlp-notes.md` and driven by
  `skills/superframes-acquire/scripts/superframes/`.
- **What this repo ships:** its own shell code. yt-dlp is not bundled.
- **Legal note:** yt-dlp's legality depends on what you download and where you are. The pipeline
  requires a licence class per asset and blocks delivery on `unknown`; it does not grant rights.

## Agent method skills

The working method in `skills/superframes-edit/references/method.md` and the repo's contribution
rules were informed by these projects. They are **not** vendored as installable skills; the method
is distilled, not copied.

| Project | Licence | What informed us |
| --- | --- | --- |
| [obra/superpowers](https://github.com/obra/superpowers) | MIT | plan-then-execute, verification before completion, systematic debugging |
| [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) | MIT | SPEC-first workflow, doubt-driven development, code review discipline |
| [anthropics/skills](https://github.com/anthropics/skills) | Apache-2.0 (per-skill licences vary) | the SKILL.md format, progressive disclosure, skill authoring rules |
| [mattpocock/skills](https://github.com/mattpocock/skills) | MIT | repository conventions, skill scope |
| [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) | MIT | audit and review passes, restraint |
| [morluto/rea](https://github.com/morluto/rea) | see upstream | end-to-end agent harness patterns |
| [wayfinder](https://www.marwieang.com/wayfinder-skill.md) | author's terms | the question protocol, decision labelling, roadmap format |

## Inherited third-party components

The HyperFrames fork carries its own dependencies and notices. The ones that ship inside this
repository rather than being installed from npm:

| Component | Licence | Where |
| --- | --- | --- |
| [mediabunny](https://github.com/Vanilagy/mediabunny) | MPL-2.0 | Studio metadata extraction |
| [three.js](https://threejs.org) r185 | MIT | vendored in several 3D registry blocks |
| [Parakeet TDT 0.6B v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) (NVIDIA) | CC-BY-4.0 | downloaded on demand by `hyperframes models install parakeet`, not shipped |
| [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) | Apache-2.0 | speech runtime for the above |
| Bundled fonts in `skills/hyperframes/assets/` | see the `OFL-*.txt` beside each | Inter, EB Garamond, JetBrains Mono and others under the SIL Open Font License |

The full upstream notice list is preserved in the HyperFrames source tree and in `CREDITS.md`.

## What this repository claims

- Its own code: the four SuperFrames skills, the five shell scripts, the verification scripts, the
  merged README and stage references.
- Nothing else. Everything merged is credited above, with its licence.

If you believe something here is credited incorrectly, open an issue and it will be fixed.
