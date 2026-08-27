# GLPill — App Store Submission Kit

## App identity

| Field | Value |
|---|---|
| App name (30 chars max) | `GLPill: GLP-1 Pill Tracker` (26 chars) |
| Subtitle (30 chars max) | `Daily pill, weight & doses` (26 chars) |
| Bundle ID | `com.ayushgupta.glpill` |
| Primary category | Health & Fitness |
| Secondary category | Medical |
| Age rating | 12+ (medical/treatment information) |
| Price | Free — **no in-app purchases, no subscriptions** (paywall removed in `2c24573`) |

## Keywords (100 chars max)

```
glp1,pill,orforglipron,foundayo,rybelsus,tracker,semaglutide,weight,loss,dose,medication,reminder
```
(97 chars. Note: competitor apps use drug names descriptively; keep them in keywords, never in the app name.)

## Description

```
GLPill is the companion app built for GLP-1 pills — Foundayo® (orforglipron), Rybelsus® (semaglutide), and compounded oral GLP-1s.

Injections had their apps. Your daily pill deserves one too.

STAY CONSISTENT
• One-tap daily dose logging with streaks
• Smart daily reminder at your time
• Rybelsus® mode: automatic 30-minute empty-stomach timer — we tell you the exact minute you can eat

FOLLOW YOUR PLAN
• Enter your prescriber's dose plan and always know your current step
• See when your next dose step starts

WATCH IT WORK
• Weight trend chart and milestones
• Protein & water targets to help protect muscle
• Share-ready progress cards (no medication name on them)

WALK INTO APPOINTMENTS PREPARED
• 4-week doctor report: adherence, doses, weight change, side effects

PRIVATE BY DESIGN
• No account. No servers. No analytics. Every data point stays on your iPhone.

GLPill is free. No account, no subscription, no ads.

GLPill is a tracking tool, not medical advice. Always follow your prescriber's instructions. Foundayo® is a trademark of Eli Lilly and Company. Rybelsus® is a trademark of Novo Nordisk A/S. GLPill is not affiliated with or endorsed by either company.
```

## Promotional text (170 chars)

```
Built for the new GLP-1 pills. Daily streaks, the Rybelsus 30-minute timer, weight trends, and a doctor-ready report — all private, all on your iPhone.
```

## Monetization — NONE (read this before touching subscriptions)

**The app ships free.** Commit `2c24573` deleted `SubscriptionStore.swift`, `PaywallView.swift`,
`PremiumGate.swift`, `Entitlement.swift` and `GLPill.storekit`. There is no `import StoreKit`
anywhere in `App/Sources`.

**Do NOT reintroduce subscription language into any metadata.** The 2026-08-04 rejection
(Guideline 2.1(b)) happened because the App Review notes still said "this is a subscription app…
start the 7-day free trial", while no IAP products were submitted. Metadata that promises a
purchase the binary can't deliver is an automatic rejection.

Current App Store Connect state (verified 2026-08-27):

- Subscription group **"Pro Subs"** (ID `22247155`) still exists with `glpill.pro.monthly` and
  `glpill.pro.yearly`, both in **Prepare for Submission** — created, never submitted, not attached
  to any version. Harmless while dormant; leave them unless you actually ship a paywall.
- App Privacy: **"Data Not Collected"** ✅
- Privacy Policy URL: `https://glpillapp.com/privacy.html` (NOT the `glpill-privacy.vercel.app` one)

If you ever do monetize: re-add StoreKit code first, ship the paywall in a build, *then* attach the
products to that version. Never metadata-first.

## iCloud / CloudKit capability (required for data sync — do this in Xcode once)

GLPill syncs user data through the user's **own private iCloud** (CloudKit private database) so a paying user never loses their history on reinstall or a new phone. The entitlement is already in the project (`App/Resources/GLPill.entitlements`, container `iCloud.com.ayushgupta.glpill`), but the container must be **provisioned under your Apple Developer account**:

1. Open `GLPill.xcodeproj` → GLPill target → **Signing & Capabilities**.
2. Set your **Team** (this also enables automatic provisioning).
3. The **iCloud** capability should show, with **CloudKit** checked and the container `iCloud.com.ayushgupta.glpill`. If the container isn't created yet, click **+** next to Containers — Xcode auto-provisions it under your account.
4. (Optional, for real-time cross-device sync) add **Background Modes → Remote notifications** + the **Push Notifications** capability. Without these, sync still happens on app launch/foreground — which already covers reinstall and new-phone recovery.
5. **Privacy label is unaffected:** CloudKit private database is the user's own iCloud, which the developer cannot read, so the App Store answer stays **"Data Not Collected."**

## Privacy policy URL

**The URL actually set in App Store Connect is `https://glpillapp.com/privacy.html`** (verified 2026-08-27),
served from `site/` (Vercel project `glpill`). Source of truth: `site/privacy.html`, mirrored to
`web/public/privacy.html`. To update: edit `site/privacy.html`, `cp site/privacy.html web/public/privacy.html`,
then deploy the `site/` project.

⚠️ A second, **stale** copy is still public at `https://glpill-privacy.vercel.app/privacy.html`
(Vercel project `glpill-privacy`, source `docs/website/privacy.html`). It is v1.0 and wrongly claims the
app does not sync to iCloud. It is not referenced by App Store Connect — retire or redirect it.

## Review notes (paste into App Review Information)

This is the text currently live in App Store Connect (set 2026-08-27):

```
GLPill is a medication-adherence tracking tool for people taking oral GLP-1 medications (Rybelsus/semaglutide, Foundayo/orforglipron, and compounded oral GLP-1s). It provides no medical advice and no dosing recommendations - the user enters the dose plan their own prescriber gave them. Disclaimers appear on the onboarding, dose-plan, settings, and report screens.

THE APP IS COMPLETELY FREE. There is no paywall, no subscription, and no in-app purchase in this build. Nothing is gated, and no sign-in or demo account is needed to review any feature. (An earlier build had a paywall; it was removed and the app now ships fully free. The previous review notes describing a subscription were out of date - that is what this resubmission corrects.)

HOW TO REVIEW
1. Launch and complete the short onboarding - any values work.
2. On the Today tab, tap "Take today's pill" to log a dose and start a streak.
3. If Rybelsus is selected, a 30-minute empty-stomach timer starts automatically.
4. The Progress, History, and Report tabs show weight trends, dose history, and a doctor-ready 4-week summary.
5. A Home/Lock Screen widget showing the streak can be added from the widget gallery.

PRIVACY: no accounts, no servers, no analytics, no third-party SDKs. Data is stored on-device and synced only through the user's own private iCloud (CloudKit private database), which the developer cannot access. The App Privacy answer is "Data Not Collected".
```

## Screenshot plan — 6.5" only

This app record has **one iPhone slot: 6.5" Display** (accepts 1242×2688 or 1284×2778). There is no
6.9" slot. Ignore any older note claiming 6.9" is mandatory.

**Screenshots must be real app screens.** The 2026-08-04 rejection (Guideline 2.3.3) was caused by
`App/Sources/Features/Marketing/ScreenshotExporter.swift`, which renders synthetic marketing
compositions — a headline, a subtitle, and a few floating cards on a gradient, with no status bar,
nav bar, or tab bar. Apple: *"Marketing or promotional materials that do not reflect the UI of the
app are not appropriate for screenshots."* All five shots were rejected on that basis.

Capture real screens instead — boot a 6.5"-class simulator, walk the app, and use:

```
xcrun simctl io booted screenshot shot.png
```

Storyline (each must be an actual screen, not a composition):
1. Today tab with an active streak and the dose logged
2. Rybelsus 30-minute timer running
3. Progress tab — weight trend chart with milestones
4. History tab — calendar with logged days
5. Report tab — the 4-week doctor summary

`ScreenshotExporter` is `#if DEBUG` and never ships, but its output must not be uploaded to the
App Store. Keep it for social/marketing use only.

## Submission checklist

- [ ] Apple Developer Program membership active
- [ ] App Store Connect app record created (bundle ID `com.ayushgupta.glpill`)
- [ ] No subscription/IAP language anywhere in description, promo text, review notes, or privacy policy
- [ ] Privacy policy deployed + URL set (`https://glpillapp.com/privacy.html`)
- [ ] App Privacy questionnaire: Data Not Collected
- [ ] Screenshots uploaded — 6.5" slot, **real app screens** (not `ScreenshotExporter` output)
- [ ] Review notes pasted
- [ ] Build uploaded via Xcode (set your Team in Signing & Capabilities first, bump build number)
- [ ] Submit for review

## Post-approval GTM (first 30 days)

1. **Apple Search Ads** exact match: "orforglipron", "foundayo", "glp-1 pill", "rybelsus tracker" — fresh keywords, low CPT, highest intent
2. **Micro-influencer seeding** (the Pep AI playbook): 50–100 GLP-1 journey creators on IG/TikTok (10K–100K followers), flat fee, weekly posts showing streak + progress card
3. **Faceless reels** via the existing reel-editor pipeline: weight-curve reveals, "pill day" streak check-ins, Rybelsus timer demos
4. **Reddit**: value-first posts in GLP-1 communities (r/Semaglutide, r/GLP1, orforglipron threads)
5. **Meta ads** only after organic creative validates hooks
