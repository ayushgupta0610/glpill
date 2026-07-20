# Premium (cinematic B-roll) reels

The 3 `wk3-premium-*` reels use the same 3-beat template as the rest of the library
(rebuilt 2026-07-20): cinematic B-roll hook → real app screenshot → the twist endcard.
Same ethos — honest depiction of the *routine* (pill, water, morning light, real food),
never fake people, before/afters, or medical claims.

## Ready to post
- `wk3-premium-morning-demo.mp4` — "Your GLP-1 pill deserves a real routine." → app (Take
  it. Tap it. Done.) → twist endcard.
  - Caption: *The morning ritual, upgraded. Built for the daily pill — the streak, the
    30-min timer, weight trends. And it never leaves your phone. 📲 link in bio.
    #glp1 #rybelsus #foundayo #glp1community #morningroutine*
- `wk3-premium-protein.mp4` — "On a GLP-1, protein is how you keep the muscle." → app
  (Track protein, not just weight.) → twist endcard.
  - Caption: *Small appetite makes protein hard — so lead with it and track it. Privately,
    on your phone. 📲 link in bio. #glp1 #protein #musclepreservation #rybelsus #foundayo*
- `wk3-premium-30sec-morning.mp4` — "The 30-second GLP-1 morning." → app (Pill, tap, timer,
  eat.) → twist endcard.
  - Caption: *The whole morning in 30 seconds — pill, one tap, the timer runs itself. The
    private, pill-native tracker. 📲 link in bio. #glp1 #rybelsus #foundayo #morningroutine*

## Reusable B-roll pack (`broll/`)
Made with Magnific (AI), brand-matched teal/cream palette:
- `broll-pill-water-5s.mp4` — hero animated clip (pill + glass of water, morning light)
- `still-pill-water.jpg`, `still-breakfast.jpg`, `still-nightstand.jpg`, `still-hand-pill.jpg`
  — stills the build script Ken-Burns's for cheap motion in every reel.

## How it's built (repeatable)
`build_reels.py` renders each reel: PIL draws text + composites the app screenshot on the
brand gradient; ffmpeg zoompan (Ken-Burns) animates each beat and xfade stitches them.
Local ffmpeg has no drawtext/libass, so all text is PIL PNG layers. Generate new aesthetic
B-roll images with Magnific (cheap), animate only a hero into video (expensive), Ken-Burns
the stills for free motion.
