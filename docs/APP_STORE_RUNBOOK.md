# GLPill — "Once the Apple account is sorted" Runbook

The exact, ordered steps to run **when your Apple Developer account / legal-entity address is fixed**, to get the **payment plans (subscriptions)** and **CloudKit (iCloud sync)** working for a production App Store release, then submit.

Owner tags: **[YOU]** = only the account holder can do it · **[CLAUDE]** = I can do it in the repo/metadata.

Constants used everywhere:
- Bundle ID (app): `com.ayushgupta.glpill` · Widget: `com.ayushgupta.glpill.widget`
- App Group: `group.com.ayushgupta.glpill` · iCloud container: `iCloud.com.ayushgupta.glpill`
- Team: `LPR84B522G` · Subscriptions: `glpill.pro.monthly` ($6.99/mo), `glpill.pro.yearly` ($39.99/yr + 3-day free trial)

---

## Part 1 — Account & agreements (unblocks everything)

1. **[YOU]** Fix the **legal-entity address** at developer.apple.com → Account → Membership.
2. **[YOU]** App Store Connect → **Business → Agreements, Tax, and Banking**: accept the **Paid Applications Agreement**, add banking + tax. *Subscriptions cannot be reviewed or sold until this agreement is **Active**.* This is the gate — nothing below sells until it's green.

---

## Part 2 — Identifiers & capabilities (Developer portal)

Xcode auto-registers most of these on the first signed archive, but confirm they exist and have the right capabilities:

3. **[YOU]** developer.apple.com → **Identifiers**:
   - App ID `com.ayushgupta.glpill` with **App Groups**, **iCloud (CloudKit)**, **Push Notifications** enabled.
   - App ID `com.ayushgupta.glpill.widget` with **App Groups** enabled.
   - App Group `group.com.ayushgupta.glpill` exists and is assigned to **both** App IDs.
   - iCloud Container `iCloud.com.ayushgupta.glpill` exists and is assigned to the app App ID.
4. **[YOU]** In Xcode (Signing & Capabilities, team `LPR84B522G`, automatic signing): both targets resolve with **no red errors**. `App Groups`, `iCloud → CloudKit`, and `Background Modes → Remote notifications` show on the app target. (These are already in `project.yml` / entitlements.)

---

## Part 3 — Payment plans (the subscriptions) in App Store Connect

5. **[YOU]** Create the **App record**: ASC → Apps → **+** → New App. Platform iOS, name **"GLPill: GLP-1 Pill Tracker"**, bundle ID `com.ayushgupta.glpill`, primary language English (U.S.), SKU `glpill`.
6. **[YOU]** ASC → your app → **Subscriptions** → create a **Subscription Group** (e.g. "GLPill Pro"). Inside it, create **two** subscriptions with **these exact product IDs** (they must match the code and the `.storekit` file byte-for-byte, or the paywall shows nothing):
   - `glpill.pro.monthly` — **$6.99 / month**.
   - `glpill.pro.yearly` — **$39.99 / year**, and add an **Introductory Offer → Free trial → 3 days** (new subscribers).
   - Add a display name + description localization (en-US) for each, and a subscription-group display name.
7. **[YOU]** Add **App Privacy** answer = **"Data Not Collected"** (accurate — no analytics/SDKs), and paste the **Privacy Policy URL** (confirm it loads first).
8. **[CLAUDE]** Provide ready-to-paste **name / subtitle / keywords / description / promo text** (from `docs/APP_STORE.md`, all within character limits) and the App Privacy questionnaire answers.

> Why this matters: the real paywall calls `Product.products(for:)` against ASC. If the two products aren't created **and attached to the version you submit**, the app is a dead-end → automatic rejection. This is the #1 subscription-app reject cause.

---

## Part 4 — CloudKit (the "iCloud sync" thing) — the step everyone misses

SwiftData's CloudKit mirroring auto-creates the record schema in the **Development** CloudKit environment when you run a dev build. **App Store users hit the *Production* environment.** If you don't promote the schema, sync silently fails for every real user. Do this before/at submission:

9. **[YOU]** On a **real device** signed into iCloud with the dev build, exercise the app once so every model type is created: complete onboarding, log a dose, add a weight, log a side effect, open the report. This makes SwiftData register all record types in the **Development** CloudKit schema.
10. **[YOU]** Go to **CloudKit Console** (icloud.developer.apple.com) → container `iCloud.com.ayushgupta.glpill` → **Schema**. Confirm the record types exist (e.g. `CD_DoseLog`, `CD_WeightEntry`, `CD_Medication`, etc. — SwiftData prefixes with `CD_`).
11. **[YOU]** Click **Deploy Schema Changes** → promote **Development → Production**. *This is the switch that makes iCloud sync work for App Store users.* Re-run this any time you add/rename a `@Model` property before a release.
12. **[YOU]** (Push is kept) No APNs code needed — SwiftData + the Push entitlement + `Background Modes: remote-notification` (already wired) give near-real-time sync via CloudKit's silent pushes. Just ensure Push Notifications is enabled on the App ID (Part 2). The Release archive rewrites `aps-environment` to `production` automatically.

---

## Part 5 — Build, upload, submit

13. **[YOU]** Bump build number only if re-uploading (`CURRENT_PROJECT_VERSION` in `project.yml`), then `xcodegen generate`.
14. **[YOU]** Xcode → **Product → Archive** → Organizer → **Distribute App → App Store Connect** (Release, team `LPR84B522G`).
    - Security check (from the audit): confirm the archive's push entitlement is production, not development. In Organizer, or on the exported `.app`: `codesign -d --entitlements :- GLPill.app | grep aps-environment` → must read `production`. Xcode's distribution profile rewrites it automatically; this just verifies it fired (we build via XcodeGen, so don't assume).
15. **[CLAUDE]** Once the build appears in ASC: attach it, paste description/keywords/promo, upload the **screenshots** (6.9" — regenerated set including the widget), link the two subscriptions to the version, and paste the **reviewer notes** (below).
16. **[YOU]** **Submit for Review.**

---

## Reviewer notes (paste into App Review Information → Notes)

The `-uiTestUnlocked` bypass is DEBUG-only, so the reviewer faces the real hard paywall — they MUST be told how to get in:

```
GLPill is a private, on-device adherence tracker for people on oral GLP-1 pills
(Foundayo/orforglipron, Rybelsus/semaglutide). It gives NO medical or dosing
advice — the user enters the plan their prescriber gave them; disclaimers appear
on the onboarding, settings, dose-plan, and report screens.

PRIVACY: no accounts, no servers. Data is stored on-device and optionally synced
only through the user's OWN private iCloud (CloudKit private database), which the
developer cannot access. App Privacy answer is "Data Not Collected" — no analytics,
no tracking, no third-party SDKs.

HOW TO REVIEW (there is a hard paywall by design):
1. Launch and complete the short onboarding — any values work.
2. At the paywall, use a StoreKit SANDBOX Apple ID to start the 3-day free trial
   on the Yearly plan (or buy Monthly). This unlocks the full app.
3. On the Today tab, tap "Take today's pill" to log a dose and start a streak.
   If Rybelsus is selected, a 30-minute empty-stomach timer starts automatically.
   The Progress, History, and Report tabs show trends, history, and a doctor summary.
A Home-/Lock-Screen widget shows the streak (add "GLPill" from the widget gallery).
No external logins or back-end to configure. Contact us if the sandbox purchase
fails on your end and we'll assist immediately.
```

---

## Most likely rejection triggers (and that we've mitigated them)

| Risk | Mitigation (status) |
|---|---|
| Reviewer stuck at hard paywall | Reviewer notes above + StoreKit sandbox path. **Do not skip.** |
| Subscriptions not attached to version | Part 3 step 6 — attach both to the 1.0 version. |
| CloudKit sync broken for real users | Part 4 step 11 — **deploy schema to Production.** |
| Guideline 1.4.1 (medical) | App never suggests doses; disclaimers in 5 places (already in code). |
| Trademarked drug names in app name | Kept in keywords only, never the app name; non-affiliation disclaimer in metadata. |
