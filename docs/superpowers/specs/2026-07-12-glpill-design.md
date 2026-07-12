# GLPill — Design Spec (2026-07-12)

## One-liner

**GLPill** is the companion app for people on GLP-1 **pills** (Foundayo/orforglipron, Rybelsus, compounded oral semaglutide): daily dose tracking with streaks, titration progress, weight trend, side-effect logging, and a doctor-visit report — all on-device, behind a hard subscription paywall.

## Why this app (decision summary)

- Orforglipron ("Foundayo", Eli Lilly) — the first daily GLP-1 weight-loss pill — was FDA-approved 2026-04-01; Medicare Part D access opened 2026-07-01. A mass wave of pill-based users is arriving now.
- Every incumbent GLP-1 tracker (Shotsy, MeAgain, Glapp, Shotwise, ShotTrack) is injection-first in name and UX; pills are a checkbox. Nobody owns "GLP-1 pill" ASO or the pill-specific routine UX.
- Health & Fitness has the best subscription monetization in the industry (RevenueCat 2026: $0.48 median RPI at D14; 68% of revenue from annual plans).
- The influencer channel (GLP-1 journey creators) is proven by Pep AI/Cal AI/Quittr playbooks.
- Full research and citations: Notion page "GLPill — Simple High-MRR iOS App: Research & Decision Log (2026-07-12)" and `~/Documents/Last30Days/indie-ios-subscription-app-mrr-growth-raw-v3.md`.

## Product scope (MVP)

### Supported medications
| Med | Cadence | Special rules |
|---|---|---|
| Foundayo (orforglipron) | Daily pill | No food/water restrictions; titration steps (user enters prescriber plan) |
| Rybelsus (oral semaglutide) | Daily pill, morning | Empty stomach; ≤4 oz water; wait 30 min before food/drink → in-app countdown timer |
| Custom / compounded oral | Daily pill | User-configured name + dose units |

Injections are **out of scope** for MVP (that market is served; our positioning is pills).

### Features
1. **Today screen** — one-tap "Take pill" check-in with streak counter; Rybelsus mode shows a 30-minute "you can eat at HH:MM" countdown after logging; protein (g) and water (ml/oz) quick counters with daily targets (defaults: 100 g protein, 2000 ml water; editable in Settings); side-effect quick-log chips.
2. **Titration tracker** — user enters their prescriber's dose plan as ordered steps (dose + duration in weeks). App shows current step, days into step, and next step date. Strictly displays the user-entered plan; no dose recommendations, ever.
3. **Progress** — manual weight entries, Swift Charts trend line, total lost / to-goal, milestone flags every 5 lb (or 2 kg). (Apple Health import deferred to v1.1 to keep MVP review surface minimal.)
4. **History** — calendar-style log of doses taken/missed and side-effect entries.
5. **Doctor report** — generated plain-text summary of the last 4 weeks (adherence %, weight change, dose steps, side-effect frequency/severity) via share sheet.
6. **Share card** — rendered progress image (streak, weight lost, weeks on med — no med name on the card by default for privacy) via `ImageRenderer` + `ShareLink`.
7. **Reminders** — daily local notification at user-chosen time; Rybelsus logs schedule a one-off "30 minutes are up" notification.
8. **Onboarding → hard paywall** — med selection → dose/titration setup → weight + goal → reminder time → paywall. App is unusable without an active subscription or trial (Quittr/Cal AI pattern).

### Explicit non-goals (MVP)
- No calorie/food-photo tracking (don't fight MyFitnessPal/Cal AI; protein+water counters only)
- No accounts, no backend, no analytics SDK — all data on-device (privacy label: "Data Not Collected")
- No Apple Health integration in MVP (v1.1: read-only weight import)
- No Android, no injections, no AI features (v2 candidates: AI meal protein estimate, food-noise journal insights)
- No community/social features

## Monetization

- StoreKit 2, auto-renewable subscriptions in one group "GLPill Pro":
  - `glpill.pro.monthly` — $6.99/month
  - `glpill.pro.yearly` — $39.99/year with 3-day free trial (anchor; displayed as "$0.77/week")
- Hard paywall at end of onboarding; entitlement re-checked via `Transaction.currentEntitlements`; restore purchases in Settings and on paywall.
- Local StoreKit configuration file for dev/testing; App Store Connect products to be created at submission time with matching IDs.

## Architecture

- **SwiftUI + SwiftData, iOS 17+, XcodeGen project** (`project.yml`), no third-party dependencies.
- MVVM-lite: views + small observable stores; pure logic extracted into testable value-type services.
- Feature-first folders, files ≤ ~300 lines:

```
App/
  Sources/
    App/            GLPillApp, RootView (routing: onboarding vs paywall-lock vs main tabs)
    Core/
      Models/       Medication, TitrationStep, DoseLog, WeightEntry, SideEffectLog, IntakeDay, UserSettings (SwiftData @Model + enums)
      Logic/        StreakCalculator, TitrationProgress, WeightStats, ReportComposer, UnitFormat (pure, unit-tested)
      Storage/      ModelContainerFactory, PreviewData
      Purchases/    SubscriptionStore (StoreKit 2), Entitlement
      Notifications/ ReminderScheduler
      Theme/        Colors, Typography, Components (Card, PillButton, StatBadge)
    Features/
      Onboarding/   6 steps + OnboardingStore
      Paywall/      PaywallView
      Today/        TodayView, TodayStore, EatTimerView, IntakeCountersView, SideEffectSheet
      Progress/     ProgressView(chart), WeightEntrySheet, ShareCardView
      History/      HistoryView (month grid + day detail)
      Report/       ReportView (preview + ShareLink)
      Settings/     SettingsView, TitrationEditor, MedicationEditor
  Tests/            Unit tests for Core/Logic + SubscriptionStore gating + ReportComposer
  Resources/        Assets.xcassets, Localizable, PrivacyInfo.xcprivacy, GLPill.storekit
project.yml
docs/
```

- **Data flow**: SwiftData `@Query` drives views; writes go through small store methods; logic services are pure functions over fetched values (no hidden state), matching the immutability preference where the framework allows.
- **Error handling**: storage failures surface as non-blocking alerts with retry; StoreKit errors mapped to friendly paywall messages; notification permission denial degrades gracefully (banner in Settings).
- **Input validation**: weight entries bounded (25–500 kg / 55–1100 lb), dose values > 0, titration steps ordered; validation lives in the logic layer with unit tests.

## Compliance & safety

- Medical disclaimer on onboarding + Settings: tracking tool, not medical advice; consult your prescriber; never change doses based on the app.
- Drug names used descriptively with ® and "not affiliated with Eli Lilly / Novo Nordisk" notice (Shotsy/MeAgain pattern).
- Privacy policy (static page in `docs/website/privacy.html`, deployable to Vercel/GitHub Pages) — required for App Store submission.

## Testing

- TDD for `Core/Logic` (streaks incl. timezone/day boundaries, titration progression, weight stats, report composition, unit conversion) and paywall gating state machine.
- StoreKit tested against the local `.storekit` configuration.
- Build verification: `xcodebuild build test` on iPhone 17 Pro simulator.
- Manual QA pass on simulator for flows; screenshots captured for App Store.

## Success criteria (build phase)

1. `xcodebuild test` green (all unit tests pass).
2. App builds and runs on iPhone 17 Pro simulator: onboarding → paywall (trial via local StoreKit config) → log dose → streak increments → weight chart renders → report shares.
3. App Store submission checklist produced (metadata, keywords, screenshots plan, privacy answers, review notes).

## Launch checklist (Ayush, post-build)

1. App Store Connect: create app, subscription group + 2 products (IDs above), attach to app version.
2. Deploy privacy policy page; paste URL into App Store Connect.
3. Screenshots (6.7" + 6.1") from simulator; keywords: orforglipron, foundayo, rybelsus, glp-1 pill, glp1 tracker, semaglutide.
4. Submit for review with review notes (test instructions; note that all data is local).
5. GTM: Apple Search Ads exact-match on fresh keywords; 50–100 GLP-1 micro-influencer outreach; faceless reels via existing pipeline; Reddit value-first seeding.
