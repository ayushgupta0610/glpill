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
| Price | Free with in-app subscriptions |

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

GLPill Pro: $6.99/month or $39.99/year with a 3-day free trial. Subscriptions renew automatically until cancelled in Settings.

GLPill is a tracking tool, not medical advice. Always follow your prescriber's instructions. Foundayo® is a trademark of Eli Lilly and Company. Rybelsus® is a trademark of Novo Nordisk A/S. GLPill is not affiliated with or endorsed by either company.
```

## Promotional text (170 chars)

```
Built for the new GLP-1 pills. Daily streaks, the Rybelsus 30-minute timer, weight trends, and a doctor-ready report — all private, all on your iPhone.
```

## Subscription setup (App Store Connect)

1. Create subscription group: **GLPill Pro**
2. Products (IDs must match exactly — they're hardcoded in `SubscriptionStore.swift`):
   - `glpill.pro.monthly` — $6.99/month
   - `glpill.pro.yearly` — $39.99/year + **3-day free trial** introductory offer
3. Localization (en-US): display name "GLPill Pro Monthly" / "GLPill Pro Yearly", description "Unlimited tracking, reports and reminders."
4. Attach both products to the app version before submitting (missing this is the #1 rejection cause for subscription apps).
5. App Store Connect → App Privacy: answer **"Data Not Collected"** (accurate: no accounts, no analytics, local-only storage).
6. Paid Apps agreement + banking must be active before subscriptions go live.

## Privacy policy URL

Deploy `docs/website/privacy.html` (Vercel/GitHub Pages) and paste the URL into App Store Connect. Required field.

## Review notes (paste into App Review Information)

```
GLPill is a medication-adherence tracking tool for users of oral GLP-1 medications. It provides no medical advice and no dosing recommendations — users enter the dose plan given by their own doctor. All data is stored locally on device; there are no accounts or servers.

To test: complete onboarding (any values work), then the paywall appears. Use a sandbox account to start the free trial. The daily flow is: tap "Take today's pill" on the Today tab.
```

## Screenshot plan (6.9" + 6.5" required)

Use the simulator (iPhone 17 Pro Max for 6.9"). Suggested storyline:
1. Today screen with an active streak — headline "One tap a day"
2. Rybelsus timer running — "We time the 30-minute wait for you"
3. Progress chart trending down — "Watch it work"
4. Doctor report — "Walk into appointments prepared"
5. Paywall/features — "Private by design — no account, no servers"

Capture: `xcrun simctl io booted screenshot shot.png` after walking the app with the StoreKit config active (run from Xcode).

## Submission checklist

- [ ] Apple Developer Program membership active
- [ ] App Store Connect app record created (bundle ID `com.ayushgupta.glpill`)
- [ ] Subscription group + 2 products created and attached to version
- [ ] Privacy policy deployed + URL set
- [ ] App Privacy questionnaire: Data Not Collected
- [ ] Screenshots uploaded (6.9" mandatory; 6.5" auto-scales)
- [ ] Review notes pasted
- [ ] Build uploaded via Xcode (set your Team in Signing & Capabilities first, bump build number)
- [ ] Submit for review

## Post-approval GTM (first 30 days)

1. **Apple Search Ads** exact match: "orforglipron", "foundayo", "glp-1 pill", "rybelsus tracker" — fresh keywords, low CPT, highest intent
2. **Micro-influencer seeding** (the Pep AI playbook): 50–100 GLP-1 journey creators on IG/TikTok (10K–100K followers), flat fee, weekly posts showing streak + progress card
3. **Faceless reels** via the existing reel-editor pipeline: weight-curve reveals, "pill day" streak check-ins, Rybelsus timer demos
4. **Reddit**: value-first posts in GLP-1 communities (r/Semaglutide, r/GLP1, orforglipron threads)
5. **Meta ads** only after organic creative validates hooks
