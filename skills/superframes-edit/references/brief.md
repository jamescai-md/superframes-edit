# Stage 0 — Intake and the spec

A video that starts from a vague sentence and ends with a render is a video nobody asked for. This stage converts a request into `SPEC.md`, a file short enough to reread before every edit and precise enough that two people would build the same film from it.

## Ask only what changes the output

Ask when the answer changes a number, a file or a stop. Do not ask when the default is obviously right or when the request already said it.

| Ask | Skip |
| --- | --- |
| Length, when no duration is stated and the request implies a real video | Length for a 5-second test clip |
| Aspect ratio, when the destination platform is unstated | Aspect when they said "vertical", "TikTok", "Reels" |
| Voice choice, when there is a script and no voice specified | Voice when there is no script |
| A reference file, when they said "like this" and gave nothing | A reference when matching is not claimed |
| Whether an existing project should be edited in place | Whether to make a new folder when none exists |
| Licence-sensitive content, when a logo, song or face is involved | Anything already answered in an earlier turn |

Ask in one message, numbered, with your recommendation first. Never ask six questions one at a time.

## `SPEC.md`

Write it at the project root. Sections are mandatory; a section with nothing in it says "none".

```markdown
# SPEC

## Delivery
- Duration: 18.0 s (540 frames at 30 fps)
- Dimensions: 1920x1080, 1:1 pixels, 30.000 fps CFR
- Masters: H.264 High, yuv420p, 16 Mbps, AAC 320k 48 kHz
- Derivatives: 1080x1920 vertical, 1080x1080 square
- Destination: product page hero, then Instagram

## Intent
One sentence a stranger would understand. "A 18-second launch film that makes the
new export button feel inevitable."

## Audience and moment
Who watches it, where, on what screen, with sound or without.

## Beats
| # | In | Out | What happens | Sound |
| --- | --- | --- | --- | --- |
| 1 | 0.0 | 2.5 | Wordmark resolves out of grain | low swell |
| 2 | 2.5 | 9.0 | Three shots of the product in use | music body |
| 3 | 9.0 | 15.5 | The button, one decisive press | button + riser |
| 4 | 15.5 | 18.0 | End card, logo, URL | tail |

## Numbers
Every adjective from the request, resolved. "Fast" is 120 ms in, 180 ms out.
"Premium" is 0.35 grain, 8% vignette, 35 mm depth of field, #F4F1EA paper.
"Punchy" is -3 dB transient peaks, 90 ms attack.

## Palette and type
Six hex values, two families, one numeric type scale.

## Constraints
What must not appear. Legal copy. Brand rules. Music licence class.

## Out of scope
Written down so it does not creep back in at stage 4.
```

## Turning adjectives into numbers

The most common failure in AI-assisted video is a spec made of moods. Convert before building, because a frame is a number and a mood is not.

| Vague | Becomes |
| --- | --- |
| "snappy" | 120–160 ms ease-out, 1–2 frame hold at the end |
| "premium" | 400–600 ms ease-in-out, max 3 simultaneous elements, 8–12% negative space margin |
| "cinematic" | 2.39:1 or 1.85:1 crop, 24 fps, shallow focus simulation, teal-orange split or a single graded source |
| "energetic" | cut every 0.8–1.6 s, 2–4% scale punch on each cut, kick-synced hits |
| "calm" | cuts every 3–5 s, continuous slow push, no scale punches |
| "minimal" | one type family, two weights, three colours, one idea per beat |
| "warm" | 2700–3200 K white balance, +6 saturation on oranges, -4 on blues |
| "clean" | no grain, no vignette, 4 px rule consistently, aligned optical grid |

If the person rejects your numbers, replace them with theirs. Never proceed on an undefined adjective.

## Stop conditions

Do not leave this stage while any of these is true:

- Duration, fps and dimensions are unresolved.
- The beat table has a gap or an overlap.
- A licence-sensitive element has no stated licence class.
- The request contradicts the destination (a 4:5 master for a 16:9 slot).
- "Make it better" is unanswered: ask what better means in numbers, or propose three concrete directions with numbers attached and let them pick.

## Re-entry

A later turn that changes the brief updates `SPEC.md` first, then the project. A spec that drifts from the build is worse than no spec: the next agent trusts the spec.
