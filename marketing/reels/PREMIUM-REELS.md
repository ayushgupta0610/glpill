# Premium (cinematic B-roll) reels

An upgraded reel style: real-feeling aesthetic B-roll behind clean text overlays, instead of flat gradient+text. Same ethos — honest depiction of the *routine* (pill, water, morning light, real food), never fake people, before/afters, or medical claims.

## Ready to post
- `wk3-premium-morning-demo.mp4` (16.6s) — "Your GLP-1 pill deserves a real routine" → take it / tap it → the 30-min timer → "you can eat now". Add trending audio in-app.
  - Caption: *The morning ritual, upgraded. Built for GLP-1 pills — daily streaks, the 30-min timer, weight trends. 📲 link in bio. #glp1 #rybelsus #foundayo #glp1community #morningroutine*

## Reusable B-roll pack (`broll/`)
Made with Magnific (AI), brand-matched teal/cream palette:
- `broll-pill-water-5s.mp4` — hero animated clip (pill + glass of water, morning light)
- `still-pill-water.jpg`, `still-breakfast.jpg`, `still-nightstand.jpg`, `still-hand-pill.jpg` — stills; use with ffmpeg Ken-Burns (slow zoom) for cheap motion in future reels.

## How it was built (repeatable, credit-wise)
1. Generate aesthetic B-roll **images** first (cheap) → pick winners.
2. Animate only the hero into **video** (expensive) — 1 clip, not all.
3. Ken-Burns the stills via ffmpeg zoompan (free motion).
4. Text via PIL PNG overlays + a dark bottom scrim for legibility (local ffmpeg has no drawtext/libass).
