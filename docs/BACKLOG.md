# GLPill — Idea & Feature Backlog

A living list so good ideas don't evaporate. Nothing here is committed; it's a menu to pick from once we have real users and real signal. Ordered loosely by leverage-vs-effort. **Guiding rule:** don't build the social/server features speculatively — launch the private tracker, get 100+ users, talk to them, then let their behavior decide.

## Growth / network effects (need a lightweight backend — first thing that breaks "zero-server")
- **Referral program** — invite a friend; both get a reward if the friend subscribes (e.g. a free month via Apple Offer Codes). Pure growth lever, no health data shared (just an invite code). Highest-value of the social ideas. Needs a small service for attribution + reward fulfillment. *Build after launch, once there are users to refer.*
- **Accountability buddy (opt-in)** — invite ONE friend to keep each other's streak honest; shares the *streak only*, never weight. Fits the core value prop (consistency) and respects the privacy-sensitive audience. The "good" version of the social idea.
- **Opt-in shared progress / weekly leaderboards** — gamified, friends see progress if allowed. ICP-uncertain: GLP-1 is a stigmatized/often-secret journey and we lean hard on "Private by design," so a public leaderboard may be exactly wrong for half the audience. Validate demand before building. *Do NOT build blind.*
- **Own subreddit (r/GLPill or similar)** — MeAgain runs r/MeAgain_GLP1. A founder-run community is a durable, owned channel + support surface. Low effort, revisit at ~month 2–3.
- **Refill reminders** — nudge when it's time to reorder the med; natural place for a telehealth/pharmacy affiliate (creators already push these).

## Product depth (privacy-safe, no backend needed)
- **Apple Health import (weight)** — already scoped as v1.1 in the design spec; read-only, opt-in. Removes manual weigh-in friction.
- **Pill-bottle scan → auto-setup** — point camera at the Rx label to prefill medication + dose. A 2-second "whoa" onboarding moment; also our reserved lever if creator-driven installs convert poorly (makes the app more filmable).
- **Maintenance / off-ramp mode** — a dedicated phase for after goal weight, which is exactly where most trackers abandon people. Strong retention play; the audience (see @jasmines.best.life "No Bullshit Maintenance") clearly wants it.
- **5-lb milestone chart annotations** — from the original spec, unimplemented. Small delight.
- **Bigger streak celebrations at day 7 / 30** — from the UX audit. Cheap dopamine that drives retention.
- **AI meal → protein estimate (photo)** — v2 candidate. Careful not to become a calorie-tracker (don't fight MyFitnessPal); keep it protein-only, on-brand.
- **Food-noise journal insights** — light AI over the side-effect/notes log. v2.

## Platform & delight (iOS-native, high fit for a daily-habit app)
- **Home/Lock Screen widget** — ✅ SHIPPED (2026-07-15, first post-launch feature). Streak flame + count + today's status ("Taken today" / "Take today's pill") on the brand gradient; systemSmall + Lock Screen circular/rectangular. Screenshot-worthy by design (growth lever, per MeAgain's viral capybara widget). Data via App Group snapshot — no CloudKit in the extension. See docs/WIDGET.md.
- **Live Activity / Dynamic Island for the Rybelsus 30-min timer** — the countdown lives in the Dynamic Island. Near-perfect fit for our signature feature; very demoable in reels.
- **Apple Watch app / complication** — log the dose from the wrist. Later.
- **Real-time cross-device CloudKit push** — add Background Modes → Remote notifications + Push capability so sync is instant, not just on launch/foreground. Provisioning step is in APP_STORE.md; currently launch/foreground sync already covers reinstall/new-phone.

## Monetization / retention
- **"Wrapped"-style monthly recap card** — shareable summary of the month's streak + progress; doubles as organic content the user posts for us.
- **Annual paywall experiments** — copy/ordering tests (not price) once we have funnel data.

## Market expansion (later, deliberate)
- **Injections support** — explicitly out of MVP scope (that market is served), but a natural TAM expansion once we own the pill niche.
- **Wider availability** — US launch first; UK/CA/AU is a one-click add and unlocks the strong UK Mounjaro/Rybelsus creator scene (already flagged).
- **Android** — out of scope; only if iOS proves the model.

## Notes
- Anything with accounts/servers changes the "Data Not Collected" privacy label — a real tradeoff against the current positioning. Weigh per feature.
- Add new ideas here as they come up rather than losing them in chat.
