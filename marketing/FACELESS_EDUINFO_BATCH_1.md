# GLPill — Faceless Eduinfo Content Batch #1 (2026-07-20)

14 ready-to-produce, **faceless** content packages for @glpillapp. No face, no fabricated
"journey." Pure educational/informational content built on the formats that faceless health
pages actually go viral with in 2026, each anchored to a **verified** fact and the GLP-1
**pill** wedge, with the app woven in softly → **waitlist** (app isn't live yet).

## Why this design (the short version)
- **Faceless, edu-first.** Ayush is not the patient; we don't fake a body/journey. We teach.
- **Niche = the GLP-1 *pill*** (Rybelsus / Foundayo / orforglipron), not "weight loss" (saturated).
  This is also the ASO/SEO wedge.
- **Built for the 2026 algorithm:** the #1 ranking signal is the **DM-share** ("send this to
  someone starting the pill") and the **save** ("keep this for week 1"). Every piece has a
  built-in reason to send or save.
- **Formats chosen from research:** text-over-b-roll fact reels (the 100K faceless workhorse),
  saveable "normal vs flag" carousels, aesthetic "romanticize the routine" b-roll, and faceless
  high-protein food content.

## Hard guardrails (baked into every piece)
1. **No fabrication.** Every number/claim traces to a verified source (FDA label via DailyMed,
   MedlinePlus, PMC). Sources listed per piece. No invented weight-loss numbers, no testimonials,
   no before/afters.
2. **No medical advice.** Everything is framed "commonly discussed / general info / talk to your
   prescriber." Keeps the 12+ posture and avoids getting reported.
3. **Stigma-safe.** Celebrate the *routine, consistency, and knowledge* — never the drug as an
   "easy way out," never a body.
4. **Soft sell.** No hard pitch inside the video. CTA lives in the caption + pinned first comment.
5. **No automation.** CTAs route via **link in bio + pinned comment**; "comment a word" lines are
   *engagement bait only* (you reply by hand or just point to bio) — do NOT wire an auto-DM tool.

## Production notes (fits your existing pipeline)
- **Reels** → `marketing/reels/build_reels.py` 3-beat pattern: **BEAT 1 hook** over b-roll,
  **BEAT 2 app** screenshot on brand gradient, **BEAT 3 endcard** (the privacy twist). 1080×1920,
  ~9.5s, silent — add trending audio in-app. Text = PIL layers (no libass locally).
- **B-roll you already own** (`reels/broll/`): `broll-pill-water-5s.mp4`, `still-pill-water.jpg`,
  `still-hand-pill.jpg`, `still-nightstand.jpg`, `still-breakfast.jpg`. New b-roll (water pour, timer)
  = shoot 5s clips on the phone; no faces.
- **Faceless food b-roll — GENERATED 2026-07-20** (Magnific / Recraft V4.1, 9:16, in `reels/broll/`):
  `food-breakfast-flatlay.png` (eggs + Greek yogurt + cottage cheese) · `food-greek-yogurt.png` ·
  `food-cottage-cheese.png` · `food-protein-shake.png` · `food-protein-sources.png` (chicken, eggs,
  tofu, edamame, lentils spread). 768×1344 — fine for Ken-Burns b-roll; upscale via `images_upscale`
  if you want crisper stills.
- **Carousels** → same PIL approach as `marketing/carousels/NN-*/01..06.jpg` (5–6 slides).
- Canonical copy/voice lives in `MESSAGING.md`. **Two existing carousels already cover
  `10-side-effects` and `06-protein`** — the packages below are *new angles*; glance at those two
  first to avoid duplicating a slide.

## Reusable CTA kit (pick one per post; rotate)
- **Bio link:** `glpillapp.com` — set bio to: *"The app built for the GLP-1 pill 💊 Join the
  waitlist → be first when it drops."*
- **Pinned first comment (post it yourself within 60s):** *"We're building the tracker made for the
  GLP-1 *pill* (the 30-min timer, streaks, private-by-design). Join the waitlist → glpillapp.com 🤍"*
- **Caption CTA lines (rotate):**
  - *"Save this for your week-1 self."*
  - *"Send this to someone who just started the pill."*
  - *"Building the app for exactly this — link in bio to get on the waitlist."*
- **Engagement bait (drives comments, NOT an auto-DM funnel):**
  - *"Rybelsus or Foundayo — which pill are you on? 👇"*
  - *"What's the one thing you wish someone told you in week 1?"*

## Bio + attribution links (#4)
**Instagram bio (≤150 chars, matches the live site "The app for GLP-1 pills"):**
> The app built for the GLP-1 pill 💊
> Rybelsus · Foundayo · oral GLP-1
> Private by design → join the waitlist ↓

**Bio link (paste as your one bio URL):**
`https://glpillapp.com/?utm_source=instagram&utm_medium=bio&utm_campaign=faceless_eduinfo`

GA4 (`G-3WKYBWQRFP`, already live on the site) auto-parses these `utm_*` params into the session's
source / medium / campaign — so any `waitlist_signup` from that visit shows up as
**instagram / bio / faceless_eduinfo**. No site change needed.

**Per-post Story link stickers (granular — add `utm_content`):**
Base: `…glpillapp.com/?utm_source=instagram&utm_medium=story&utm_campaign=faceless_eduinfo&utm_content=<id>`

| Post | utm_content | Post | utm_content |
|---|---|---|---|
| 1A 30-min rule | `1a-30min-rule` | 3B timeline | `3b-timeline` |
| 1B more-water | `1b-water-rule` | 3C calm nausea | `3c-calm-nausea` |
| 1C new pill | `1c-new-pill` | 6A ritual | `6a-ritual` |
| 1D nausea month 2 | `1d-nausea-pattern` | 6B 30 minutes | `6b-30-minutes` |
| 2A hit protein | `2a-hit-protein` | 6C day 30 | `6c-day30` |
| 2B protein breakfast | `2b-breakfast` | 2C why protein | `2c-why-protein` |
| 2D no-cook protein | `2d-nocook` | 3A normal-vs-flag | `3a-normal-vs-flag` |

Notes: feed posts can't carry per-post links (bio is one link) — use the **bio link** for feed, the
**sticker link** for Stories. IG passes query strings through on both. Verify in GA4 → Reports →
Acquisition → Traffic acquisition, filter Session source/medium = `instagram`.

---

# FORMAT #1 — Fact-drop reels (×4)
*Text over aesthetic b-roll + trending audio. One surprising, verified fact. The faceless workhorse.*

## 1A · "The #1 mistake in week one"
- **Hook (0–2s, on-screen):** "If you take the GLP-1 pill wrong, you might be getting a *fraction*
  of the dose."
- **Length/format:** ~9s reel, silent + trending audio.
- **Beats:**
  1. **HOOK** over `broll-pill-water-5s.mp4` — text: *"Rybelsus has one rule most people break."*
  2. **FACT** over `still-pill-water.jpg` — text: *"Empty stomach. ≤4 oz plain water. Then wait
     30 min — no food, no coffee, no other pills."*
  3. **APP** — screenshot of the empty-stomach **timer** — text: *"So you never guess the 30 minutes."*
  4. **ENDCARD** — *"Built for the GLP-1 pill. glpillapp.com"*
- **Caption:** *Rybelsus is the only GLP-1 you swallow — and it depends on a 30-minute empty-stomach
  window to actually absorb. Food, coffee, or a big glass of water in that window can cut how much
  gets in. Take it first thing, tiny sip of plain water, then wait. (General info from the FDA label
  — your prescriber knows your plan.) Send this to someone starting Rybelsus.*
- **Source:** RYBELSUS FDA label (DailyMed setid 27f15fac…); MedlinePlus a619057.
- **Hashtags:** #rybelsus #glp1 #oralsemaglutide #glp1pill #glp1journey #glp1support #semaglutide
  #glp1community #weightlosssupport #rybelsusjourney

## 1B · "More water = worse" (counterintuitive)
- **Hook:** "More water makes your GLP-1 pill work *less*. Not a typo."
- **Beats:**
  1. **HOOK** over a water-pour b-roll — text: *"Everyone says 'drink more water.' Not with this pill."*
  2. **FACT** over `still-pill-water.jpg` — text: *"Rybelsus: no more than 4 oz (½ a small glass) of
     plain water. More actually lowers absorption."*
  3. **APP** — the Today card / timer — text: *"One tap to log it right, every morning."*
  4. **ENDCARD** — privacy twist: *"Most GLP-1 apps want your data. This one can't see it. glpillapp.com"*
- **Caption:** *Counterintuitive but true: Rybelsus absorbs best with a *small* sip — ≤4 oz of plain,
  still water — not a full glass, and not coffee or juice. It's a large molecule that needs a precise
  empty-stomach window. (Per the FDA label; not medical advice.) Save this for tomorrow morning.*
- **Source:** RYBELSUS FDA label (DailyMed); MedlinePlus a619057.
- **Hashtags:** #rybelsus #glp1 #oralsemaglutide #glp1tips #glp1pill #semaglutide #glp1community
  #glp1journey #weightlossjourney #glp1support

## 1C · "The new pill that breaks the rules" (timely / newsjack)
- **Hook:** "The newest GLP-1 pill doesn't care when you take it."
- **Beats:**
  1. **HOOK** over `still-hand-pill.jpg` — text: *"Rybelsus = strict morning ritual. The new one?
     Not so much."*
  2. **FACT** — text: *"Orforglipron (Foundayo) — FDA-approved 2026 — can be taken any time of day,
     with or without food."*
  3. **APP** — screenshot showing pill-type toggle / "no empty-stomach window" — text: *"The app
     adapts to your pill."*
  4. **ENDCARD** — *"One app for every GLP-1 pill. glpillapp.com"*
- **Caption:** *Two GLP-1 pills, two completely different routines. Rybelsus needs the empty-stomach
  30-minute window; orforglipron (Foundayo), the newest FDA-approved oral GLP-1, can be taken any time
  of day, with or without food. Handy if mornings are chaos. (General info from the FDA label.) Which
  pill are you on — Rybelsus or Foundayo? 👇*
- **Source:** FOUNDAYO (orforglipron) FDA label (DailyMed setid 8ac446c5…); FDA approval announcement.
- **Hashtags:** #orforglipron #foundayo #glp1 #glp1pill #newweightlossdrug #oralglp1 #glp1journey
  #glp1community #glp1support #weightlosssupport

## 1D · "Why nausea spikes in month 2" (pattern reveal)
- **Hook:** "If your GLP-1 side effects came back out of nowhere — this is why."
- **Beats:**
  1. **HOOK** over a calm b-roll — text: *"Side effects that eased… then spiked again?"*
  2. **FACT** — text: *"They usually spike at each *dose increase* — and ease again within ~4–8 weeks
     as your body adapts."*
  3. **APP** — screenshot of dose/side-effect log — text: *"Log it around each step-up so the pattern
     is obvious — and easy to show your doctor."*
  4. **ENDCARD** — *"glpillapp.com — private by design."*
- **Caption:** *A GLP-1 pattern nobody explains: GI side effects (nausea, etc.) tend to be worst right
  when you step up a dose, then settle over about 4–8 weeks as your body adjusts. So a "random" spike
  in month two often lines up with an increase. Tracking it around each step-up turns a vague "it got
  rough" into something your prescriber can act on. (General info; talk to your prescriber.) Save this.*
- **Source:** FOUNDAYO FDA label (DailyMed); orforglipron side-effects article (glpillapp.com).
- **Hashtags:** #glp1 #glp1sideeffects #glp1pill #rybelsus #foundayo #glp1journey #glp1tips
  #glp1support #glp1community #weightlosssupport

---

# FORMAT #3 — Side-effect carousels (×3)
*5–6 PIL slides. Save + send-to-family mechanic. All numbers FDA-label verified. New angles vs the
existing `10-side-effects` carousel.*

## 3A · "Normal vs. call your doctor" (the classic save-and-send)
- **Cover (slide 1):** *"GLP-1 pill side effects: what's normal vs. when to call your doctor 🚩
  (save this)"*
- **Slides:**
  2. *"Mostly normal & temporary — the common ones:"* nausea **(≈26–35%)**, constipation **(20–27%)**,
     diarrhea **(21–25%)**, vomiting **(13–24%)**. *"Usually mild–moderate."*
  3. *"The pattern:"* *"Worst around a dose increase → ease within ~4–8 weeks as your body adapts."*
  4. *"Gentle basics people use:"* smaller/slower meals · go easy on greasy & heavily spiced food ·
     hydrate · don't rush the dose step-ups. *"(Not medical advice.)"*
  5. *"🚩 Talk to your prescriber if:"* severe symptoms · they don't settle after weeks at a steady
     dose · you can't eat or drink normally. *"~8% stop over side effects (vs 3% on placebo) — it's a
     real conversation, not something to endure silently."*
  6. **CTA slide:** *"We're building the tracker made for the GLP-1 pill — log side effects around each
     step-up, privately. Waitlist → glpillapp.com 🤍"*
- **Caption:** *Save this so week one is less scary. These are ranges from trial data on orforglipron
  (Foundayo), not a prediction for you — plenty of people have an easier time. The point is knowing
  what's expected vs. what's worth a call. (General info from the FDA label; your prescriber and
  pharmacist are the right people for your situation.) Send it to someone just starting.*
- **Source:** FOUNDAYO FDA label (DailyMed setid 8ac446c5…).
- **Hashtags:** #glp1sideeffects #glp1 #foundayo #orforglipron #glp1pill #glp1journey #glp1support
  #glp1community #nausea #weightlosssupport

## 3B · "The side-effect timeline nobody hands you"
- **Cover:** *"The GLP-1 side-effect timeline nobody explains 📆"*
- **Slides:**
  2. *"Week 1 (starting dose):"* GI stuff shows up — nausea most common. *"Mild–moderate for most."*
  3. *"Each dose step-up:"* symptoms tend to *spike again* briefly. *"This is expected, not a setback."*
  4. *"~4–8 weeks at a steady dose:"* most people find it *eases* as the body adapts.
  5. *"Why:"* GLP-1s slow how fast your stomach empties — that's part of how they work, and what drives
     early nausea. Slow titration gives your system time to adjust.
  6. **CTA slide:** *"Track it around each step-up — GLPill (waitlist at glpillapp.com)."*
- **Caption:** *A GLP-1 timeline that makes the first months less confusing: side effects aren't
  random — they track your dose. Worst at each increase, easing over ~4–8 weeks at a stable dose.
  (General info from the FDA label; individual experiences vary — talk to your prescriber.) Save for
  your week-1 self.*
- **Source:** FOUNDAYO FDA label (DailyMed); RYBELSUS FDA label (DailyMed).
- **Hashtags:** #glp1 #glp1journey #glp1sideeffects #rybelsus #foundayo #glp1pill #glp1tips
  #glp1support #glp1community #weightlossjourney

## 3C · "5 gentle ways people calm GLP-1 nausea"
- **Cover:** *"5 things people do to calm GLP-1 nausea (not medical advice) 🤍"*
- **Slides:**
  2. *"1. Smaller, slower meals."* Big meals sit heavy when your stomach empties slowly.
  3. *"2. Ease off greasy, rich & heavily spiced food"* while symptoms are active.
  4. *"3. Hydrate"* — especially with any vomiting/diarrhea; for constipation, fluids + fiber + movement.
  5. *"4. Don't rush the titration."* Prescribers can hold you at a dose longer. Pushing up fast is a
     common cause of avoidable misery.
  6. *"5. Use timing flexibility"* (Foundayo can be taken any time of day — some pick the time that
     sits easiest). **+ CTA:** *"Track what helps → glpillapp.com waitlist."*
- **Caption:** *None of this is medical advice — your prescriber and pharmacist are the right people —
  but these are the sensible basics people lean on when GLP-1 nausea flares. The through-line: gentler,
  smaller, hydrated, unhurried. Save it, and send it to someone in a rough week.*
- **Source:** FOUNDAYO orforglipron side-effects article + FDA label (glpillapp.com / DailyMed).
- **Hashtags:** #glp1 #glp1nausea #glp1sideeffects #glp1tips #foundayo #rybelsus #glp1pill
  #glp1support #glp1community #weightlosssupport

---

# FORMAT #6 — Morning-ritual b-roll reels (×3)
*Aesthetic / ASMR "romanticize the routine." Most on-brand — the daily pill ritual IS the product.
Built for the DM-share ("this is so satisfying").*

## 6A · "Romanticize your GLP-1 pill morning"
- **Hook:** "POV: you actually look forward to your morning pill now."
- **Length/format:** ~10–12s aesthetic b-roll reel, soft/calm trending audio (no VO).
- **Beats (all b-roll, no face, close-ups):**
  1. Nightstand at dawn — pill + glass set out the night before (`still-nightstand.jpg`).
  2. Small pour of water into a nice glass.
  3. Pill taken; slow-mo `broll-pill-water-5s.mp4`.
  4. Phone shows the timer starting → **APP** streak flame lighting up (screenshot).
  5. **ENDCARD** text: *"One small ritual, every day. glpillapp.com"*
- **On-screen text (minimal):** *"the 30-second ritual that keeps the streak alive 🔥"*
- **Caption:** *Romanticize the boring part. Set the pill + a small glass of water on the nightstand
  the night before → take it the second you wake → start the timer → watch the streak grow. Tiny
  ritual, big consistency. Save this if your mornings need a reset.*
- **Source:** N/A (aesthetic; no factual claims). Ritual reflects Rybelsus best-practice from the FDA
  label (take first thing, small sip, then wait).
- **Hashtags:** #glp1 #morningroutine #glp1journey #rybelsus #glp1pill #romanticizeyourlife
  #glp1community #glp1support #wellnessroutine #that_girl

## 6B · "The 30 minutes that decide if it works"
- **Hook:** "The most important 30 minutes of a GLP-1 pill morning."
- **Beats:**
  1. Pill swallowed → **timer set to 30:00** (app screenshot, satisfying).
  2. B-roll of coffee mug waiting, untouched.
  3. Timer ticking (aesthetic close-ups: window light, kettle, book).
  4. Timer hits 0 → coffee finally poured. **APP** shows "window clear ✅".
  5. **ENDCARD** — *"So you never guess. glpillapp.com"*
- **On-screen text:** *"no food. no coffee. no other pills. just wait. ⏳"*
- **Caption:** *With Rybelsus, the 30-minute empty-stomach wait is the make-or-break step — food,
  coffee, or other pills too soon can cut how much absorbs. The hardest part is just not guessing.
  (General info from the FDA label.) Send this to your fellow 6am-pill-and-wait person.*
- **Source:** RYBELSUS FDA label (DailyMed); MedlinePlus a619057.
- **Hashtags:** #rybelsus #glp1 #oralsemaglutide #glp1pill #glp1journey #morningroutine #glp1support
  #glp1community #semaglutide #weightlosssupport

## 6C · "Day 30 and it's just automatic now"
- **Hook:** "Day 1 vs Day 30 of the pill habit."
- **Beats:**
  1. Text: *"Day 1: setting 3 alarms so you don't forget."*
  2. B-roll of the ritual, calm.
  3. Text: *"Day 30: you take it before your eyes fully open."*
  4. **APP** — the streak at 30 days 🔥 + "My Month" recap card (screenshot).
  5. **ENDCARD** — *"Consistency, not willpower. glpillapp.com"*
- **On-screen text:** *"the habit builds itself when you can see the streak 🔥"*
- **Caption:** *Nobody talks about the quiet win: the day the pill stops needing a reminder and just
  becomes… who you are in the morning. Showing up 30 days straight is the flex. Save this for the days
  it feels hard.* *(Identity/consistency — never about the scale.)*
- **Source:** N/A (no factual/medical claims; consistency framing).
- **Hashtags:** #glp1 #glp1journey #habits #consistency #glp1pill #rybelsus #foundayo #glp1support
  #glp1community #nonscalevictory

---

# FORMAT #2 — Food / "what to eat on the pill" (×4)
*Faceless food content — flatlays, no face. The strongest evergreen sub-niche.
Anchored to the verified protein framework; NO invented per-food macros.*

> **B-roll ready (in `reels/broll/`):** 2A/2B cover & hook → `food-breakfast-flatlay.png`;
> 2B/2D protein close-ups → `food-greek-yogurt.png`, `food-cottage-cheese.png`,
> `food-protein-shake.png`; 2C protein-sources → `food-protein-sources.png`.

## 2A · Carousel — "How to hit your protein when the pill kills your appetite"
- **Cover:** *"Barely hungry on a GLP-1? How to still get your protein 🍳 (save this)"*
- **Slides:**
  2. *"Why it matters:"* GLP-1s make you eat less — but fast weight loss can take *muscle* too.
     Protein while in a deficit helps protect it.
  3. *"How much?"* Many aim around **~100g/day** as a common reference — but it's individual (body
     size, activity, age). Best set with your prescriber/dietitian, not a blog.
  4. *"1. Lead with protein."* Eat the protein on your plate *first*, while appetite is strongest.
  5. *"2. Front-load breakfast."* Eggs, Greek yogurt, cottage cheese, a shake — bank protein early.
  6. *"3. Make it dense + spread it out."* Higher-protein, lower-volume foods; smaller hits across the
     day beat one big meal. **+ CTA:** *"Track protein + water privately → glpillapp.com waitlist."*
- **Caption:** *The cruel twist of GLP-1s: the thing that makes protein important (smaller appetite)
  is the same thing that makes it hard. So work *with* the appetite you have — protein first,
  front-loaded, dense, spread out. (~100g is a common reference point, not a prescription — your
  prescriber/dietitian sets your number.) Save it.*
- **Source:** MedlinePlus — Dietary Proteins; Current Obesity Reports (PMC12549762); protein-on-GLP1
  article (glpillapp.com).
- **Hashtags:** #glp1 #proteinfirst #glp1nutrition #glp1journey #highprotein #glp1pill #glp1support
  #glp1community #musclepreservation #weightlosssupport

## 2B · Reel — "Protein-first breakfast when you're barely hungry"
- **Hook:** "The breakfast trick for when the pill kills your appetite."
- **Beats (faceless food b-roll):**
  1. **HOOK** over a bright kitchen flatlay — text: *"Barely hungry? Eat *this* order."*
  2. **TIP** over food b-roll (eggs / Greek yogurt / cottage cheese) — text: *"Protein FIRST, while
     appetite's strongest. Carbs/extras after."*
  3. **APP** — protein log screenshot — text: *"See if you actually hit your target (most people
     overestimate)."*
  4. **ENDCARD** — *"glpillapp.com — private by design."*
- **Caption:** *When your appetite's tiny, order matters: eat the protein first, so if you fill up,
  you fill up on what protects your muscle. Front-loading a protein breakfast (eggs, Greek yogurt,
  cottage cheese, a shake) banks it before hunger fades further. (General nutrition info.) Send this
  to a GLP-1 friend who "isn't hungry anymore."*
- **Source:** MedlinePlus — Dietary Proteins; protein-on-GLP1 article (glpillapp.com).
- **Hashtags:** #glp1 #highproteinbreakfast #glp1nutrition #proteinfirst #glp1journey #glp1pill
  #glp1support #glp1community #weightlosssupport #glp1recipes

## 2C · Carousel — "Why protein matters *more* on a GLP-1"
- **Cover:** *"The one nutrition rule everyone on a GLP-1 repeats 🥩"*
- **Slides:**
  2. *"You're eating less overall…"* (that's how it works).
  3. *"…but rapid weight loss can take muscle, not just fat."*
  4. *"Muscle = strength + metabolism + keeping it off."* Protein in a deficit helps hold onto it.
  5. *"So: a bigger *share* of what you do eat should be protein."* Common reference ~100g/day
     (individual — set it with your prescriber/dietitian).
  6. *"Don't forget water"* — thirst cues get quiet too; helps with constipation. (On Rybelsus,
     hydrate *after* the 30-min window.) **+ CTA:** *"glpillapp.com waitlist."*
- **Caption:** *Why "prioritize protein" is in every GLP-1 conversation: eating less can cost you
  muscle along with fat, and protein is one of the main ways to protect it while you lose. (General
  info — MedlinePlus + a peer-reviewed obesity-management review; your number is individual.) Save
  + send to someone starting out.*
- **Source:** MedlinePlus — Dietary Proteins; Current Obesity Reports (PMC12549762).
- **Hashtags:** #glp1 #protein #glp1nutrition #musclepreservation #glp1journey #glp1pill #glp1support
  #glp1community #highprotein #weightlosssupport

## 2D · Reel — "3 no-cook protein foods for days you can't eat much"
- **Hook:** "3 no-cook protein foods for GLP-1 days you just can't eat."
- **Beats (faceless food b-roll):**
  1. **HOOK** — text: *"Too nauseous to cook? Keep these on hand."*
  2. **LIST** over food b-roll — text: *"Greek yogurt · cottage cheese · a protein shake"* — *"dense
     protein, low effort, small volume."*
  3. **APP** — quick protein log — text: *"Log it in 2 taps."*
  4. **ENDCARD** — *"glpillapp.com"*
- **Caption:** *On the rough days, protein has to be low-effort and low-volume. No-cook, dense options
  — Greek yogurt, cottage cheese, a shake — get protein in when a full meal is a no. (General nutrition
  info, not a meal plan — your dietitian/prescriber knows your needs.) Save this for a bad-nausea day.*
- **Source:** MedlinePlus — Dietary Proteins; protein-on-GLP1 article (glpillapp.com).
- **Hashtags:** #glp1 #highprotein #glp1nutrition #nocookmeals #glp1journey #glp1pill #glp1nausea
  #glp1support #glp1community #weightlosssupport

---

# Suggested 2-week posting sequence (1 quality post/day; never 2 same-type in a row)
| Day | Piece | Type |
|---|---|---|
| 1 | 6A Romanticize the ritual | ritual reel |
| 2 | 3A Normal vs call your doctor | carousel |
| 3 | 1A #1 mistake (30-min rule) | fact reel |
| 4 | 2A Hit your protein | carousel |
| 5 | 6B The 30 minutes | ritual reel |
| 6 | 1C New pill breaks the rules | fact reel |
| 7 | 3C 5 ways to calm nausea | carousel |
| 8 | 2B Protein-first breakfast | food reel |
| 9 | 1B More water = worse | fact reel |
| 10 | 3B Side-effect timeline | carousel |
| 11 | 6C Day 30 automatic | ritual reel |
| 12 | 2C Why protein matters more | carousel |
| 13 | 1D Why nausea spikes month 2 | fact reel |
| 14 | 2D 3 no-cook protein foods | food reel |

# What to measure (decides what to scale)
- **Sends/shares** (DM-shares) and **saves** first — they're the 2026 distribution signal and the
  strongest waitlist-intent proxy. Watch which *format* wins.
- **Waitlist signups by source** — GA4 `waitlist_signup` event on glpillapp.com. Add a UTM to the bio
  link (`?utm_source=ig&utm_medium=bio`) so IG traffic is attributable.
- **Comments** on the engagement-bait lines (Rybelsus-vs-Foundayo, "what do you wish you knew").
- **Rule:** don't judge a format before ~100 posts of trying. When one format consistently clears
  ~1,000 views + high sends, mass-produce variations of *that* template (all four are templates).
```
