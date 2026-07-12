# GLPill — GLP-1 Pill Tracker

The companion iOS app for GLP-1 **pills** (Foundayo®/orforglipron, Rybelsus®, compounded oral semaglutide): one-tap daily dose tracking with streaks, the Rybelsus 30-minute empty-stomach timer, titration plan tracking, weight trends, side-effect logging, and a doctor-visit report. Hard paywall (StoreKit 2): $6.99/mo or $39.99/yr with a 3-day free trial. No accounts, no servers — all data on-device.

## Why this exists

Orforglipron (brand Foundayo) — the first daily GLP-1 weight-loss pill — was FDA-approved April 1, 2026, with Medicare Part D access from July 1, 2026. Every incumbent GLP-1 tracker is injection-first (Shotsy, MeAgain, Shotwise…). GLPill owns the pill-user experience and its ASO keywords. Full research: `docs/superpowers/specs/2026-07-12-glpill-design.md` and the Notion research log.

## Stack

SwiftUI + SwiftData (iOS 17+), StoreKit 2, Swift Charts, UserNotifications. No third-party dependencies. Project generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen).

## Build & test

```bash
xcodegen generate
xcodebuild -project GLPill.xcodeproj -scheme GLPill \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

49 unit tests (logic, stores, models) + 2 UI tests (onboarding → paywall; full unlocked flow). UI tests use debug-only launch args `-resetData` and `-uiTestUnlocked`.

Run in Xcode with the `GLPill` scheme — the local StoreKit configuration (`App/Resources/GLPill.storekit`) enables trial/purchase testing in the simulator.

## Ship it

See `docs/APP_STORE.md` for the complete App Store submission kit (metadata, subscription product setup, privacy answers, review notes, screenshot plan, go-to-market).

## Layout

```
App/Sources/App/        entry, routing, tabs
App/Sources/Core/       models, logic (unit-tested), storage, purchases, notifications, theme
App/Sources/Features/   Onboarding, Paywall, Today, Progress, History, Report, Settings
App/Tests/              unit tests   App/UITests/  flow tests
docs/                   specs, plans, screenshots, App Store kit, privacy policy
```
