# Stage 4 — Motion

Everything in this file exists to prevent one outcome: motion that is technically present and emotionally meaningless. A tween that fires because it was easy is worse than a cut.

## The three questions

Before animating anything, answer all three. If any answer is "because it looked empty", remove the animation instead.

1. **What is the cause?** Something moved because something happened: an arrival, a press, a reveal, a consequence. Motion without a cause is decoration.
2. **What is the observer's eye doing?** Each beat has one subject. If two things move with equal weight, the eye has no home.
3. **What does the frame lose when the motion ends?** If nothing changes, the motion was noise.

## Timing that reads as professional

| Duration | Used for |
| --- | --- |
| 60–90 ms | micro feedback: a button press, a checkbox, a hairline highlight |
| 120–200 ms | UI-scale reveals, small type, chip and label entrances |
| 240–360 ms | standard element entrance, a card, a panel, a lower third |
| 400–600 ms | full-frame or hero-scale transitions, title resolution |
| 800 ms+ | deliberate, luxurious, or slow-cinema pacing only |

Above roughly 700 ms a motion stops reading as responsiveness and starts reading as a mood. That is fine, but it must be a decision.

Rules of thumb:

- **Entrance is slower than exit.** A 320 ms in and a 200 ms out feels right; the reverse feels sluggish.
- **Nothing enters and leaves in the same frame.** Leave at least two frames of hold at full state.
- **Offset simultaneous elements by 40–80 ms.** Three cards landing on exactly the same frame look like one block.
- **Total stagger under 300 ms.** Ten items at 60 ms each is 540 ms of waiting; cap the count and stagger.
- **The last frame of a clip is an end state, not a mid-motion frame.** Land it, then let it sit.

## Easing

| Curve | Where |
| --- | --- |
| `power2.out` / `cubic-bezier(.25,.46,.45,.94)` | default for entrances |
| `power3.out` | confident, premium entrances |
| `power2.in` | exits, dismissals |
| `power4.out` | fast attack, long settle — kinetic type, snappy UI |
| `back.out(1.4)` | playful overshoot, only with a friendly brand voice |
| `expo.out` | dramatic, expensive-feeling reveals |
| `sine.inOut` | continuous moves, camera drifts, ambient loops |
| `none` / `linear` | only for deliberate mechanical motion: a progress bar, a rack focus, a turntable |

In GSAP, `"power2.out"` and `"easeOutQuad"` are the same curve. In CSS, `power2.out` is `cubic-bezier(0.25, 0.46, 0.45, 0.94)`. In Remotion, `spring({frame, fps, config:{damping, stiffness}})` is the equivalent of a spring — use `Easing.out(Easing.cubic)` when you want a curve, not a bounce.

Never use `bounce` and `elastic` in professional work unless the brand is explicitly playful. Never chain `ease-in` into `ease-out` across a single continuous motion; that reads as two animations fighting.

## Transitions between shots

| Transition | Reads as | Cost |
| --- | --- | --- |
| Hard cut | confidence, rhythm | free; the default |
| J-cut / L-cut (audio leads or lags) | professional editing | needs separate audio tracks |
| Crossfade, 8–16 frames | time passing, softness | can look amateur past ~20 frames |
| Whip pan | energy, comedy | needs matched motion blur |
| Mask reveal, 12–24 frames | craft, brand | the mask must be motivated |
| Match cut on shape | sophistication | needs planning, not post |
| Zoom punch, 2–4 frames of scale | impact on a beat | cheapens if overused |
| Dip to black | chapter break | kills momentum mid-film |

Default to hard cuts. A film with a transition on every boundary reads as a slideshow. One well-placed mask reveal is worth ten crossfades.

## Kinetic type

- Animate a **mask**, not opacity alone: `clip-path: inset(0 0 100% 0)` to `inset(0 0 0 0)` in 280 ms `power3.out`.
- Word-level stagger beats letter-level except for single short words.
- Letter-spacing while animating: start at `+0.04em`, end at the designed tracking. It reads as settling.
- Never scale text from 0; below roughly 0.85 it looks like it is inflating.
- Baseline: keep text on the same baseline through the whole move unless the move *is* the baseline change.

## Camera language inside a flat frame

Simulate a camera; do not animate twenty elements.

- **Push-in:** scale 1.00 → 1.04 over the shot, `sine.inOut`. Four percent is a lot; two percent is a whisper.
- **Parallax:** background 0.98, subject 1.00, foreground 1.03, driven by one shared progress value.
- **Handheld:** a tiny sine wobble, 0.15–0.3% amplitude, 0.4–0.7 Hz. Above that it looks like a bug.
- **Rack focus:** blur 0 → 6 px on the background, 400 ms, while the subject stays sharp. Real depth blur needs a treatment pass, not a CSS filter on footage.
- **Whip:** translate plus directional blur, 6–9 frames total.

## Beat sync

If there is music, the cut grid is the music.

1. Detect onsets (stage 2) or read the tempo.
2. Build a grid of beats; place cuts and hero moments on beats, not near them.
3. Let one shot per bar break the grid deliberately; uniform sync reads as an auto-generated slideshow.
4. Silence is a tool. Cutting the music for 400 ms before a hit is louder than any riser.

## Holds and rhythm

- Vary shot length by at least 2× across a film. Even pacing is the fastest way to look machine-made.
- A deliberate hold at the end (400–800 ms) lets the last frame land.
- No element should be mid-motion when the video ends; land it or cut it.
- Do not animate everything. In a four-element frame, one moves and three hold.

## The motion audit

Run this before stage 5. Every row must be answerable.

| Check | Pass condition |
| --- | --- |
| Cause | every motion traces to an event |
| Focus | one primary subject per beat |
| Duration | within the table above, or justified |
| Easing | named, consistent within a family of moves |
| Stagger | offset present when multiple elements enter |
| Overlap | no two unrelated moves compete for the eye |
| Dead frames | none longer than ~600 ms without intent |
| Ending | every timed element lands before its end |
| Determinism | no `Date.now()`, no unseeded `random`, no `repeat: -1`, no timer |
| Sync | cuts and hero beats land on the grid when music exists |

In HyperFrames terms: `npx hyperframes snapshot --range <start>,<end>` around each transition, then look at the frames. A transition you have not looked at frame by frame is a transition you have not designed.

## Anti-patterns

| Pattern | Why it fails | Instead |
| --- | --- | --- |
| Everything fades in | no hierarchy, no cause | one cause, one subject, others hold |
| `ease-in-out` on everything | feels slow and floaty | `out` curves for entrances |
| Bouncy springs on brand work | reads as toy software | `cubic` curves, or a tiny spring |
| Motion on every word | the eye has no anchor | animate the line, emphasize one word |
| Scale-from-zero | inflating, cheap | mask reveal or scale from 0.85 |
| Looping background animation | fights the foreground, never resolves | one slow drift, or nothing |
| Identical shot lengths | machine-made rhythm | vary by 2× |
| Transition on every cut | slideshow | hard cuts, two or three deliberate transitions |
