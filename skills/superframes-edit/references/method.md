# Working method

Distilled from the agent-skill repositories this project is built with ([superpowers](https://github.com/obra/superpowers), [agent-skills](https://github.com/addyosmani/agent-skills), [anthropics/skills](https://github.com/anthropics/skills), [mattpocock/skills](https://github.com/mattpocock/skills), [ponytail](https://github.com/DietrichGebert/ponytail), [rea](https://github.com/morluto/rea), [wayfinder](https://www.marwieang.com/wayfinder-skill.md)). It is the discipline that keeps a combined pipeline from becoming a combined mess.

## The loop

1. **Understand** — read the request and the project before touching either. State the goal in one sentence and check it matches what was asked.
2. **Spec** — turn the sentence into numbers (`references/brief.md`). Ambiguity resolved here is cheap; ambiguity resolved at stage 5 is a re-render.
3. **Smallest real step** — one scene, one cut, one export. Render it. Look at it.
4. **Verify with evidence** — a check log, a frame, a duration probe. "It should work" is not a result.
5. **Broaden** — only after the small step is verified.
6. **Report** — what changed, what was verified, what was assumed, what is left.

## Evidence rules

- A claim about output requires an artefact: a file path, a `ffprobe` line, an SSIM number, a frame you actually looked at.
- Never state that a render succeeded without a non-zero file and a duration that matches the spec.
- Never state that frames look right without having opened at least one frame per distinct scene.
- When something could not be checked — no ffmpeg, no network, no reference file — say which check was skipped and why. A skipped check is a disclosure, not a pass.

## Doubt first

Before converting an assumption into code or a frame, ask: what would prove this wrong, and can I check it in under a minute? If yes, check first. Typical traps:

- The reference video is not the framerate you assumed.
- The font you named is not installed, so a fallback silently rendered.
- The audio file is mono at 44.1 kHz while everything else is 48 kHz stereo.
- The "16:9" source is actually 1912x1072 after a crop.
- The music is 128 BPM and your cuts are on a 120 BPM grid.

## Scope discipline

- Do what was asked. Additions get offered, not slipped in.
- One change per commit-shaped unit of work, with the reason in the message.
- Do not refactor a working project to make a small edit easier.
- Delete dead experiments before delivery; keep them in a scratch folder if the person may want them.

## Question protocol

Mark every decision as **User-confirmed**, **Delegated** or **Assumption**. Recommendations and silence are not agreement. Reopen a settled decision only for material new evidence, and say what changed.

When the person is unsure, explain the trade-off in numbers rather than picking for them. When they say "you decide", decide, record it as **Delegated**, and state the consequence.

## What "done" means

- The deliverable exists at the stated path, in the stated container, at the stated duration.
- Verification ran, and its summary is in `DELIVERY.md`.
- Every generated or third-party element is disclosed.
- The next person can rebuild it from the repo without asking you anything.
