# GLPill Home / Lock Screen Widget

**Status:** Shipped 2026-07-15 — first post-launch feature.

## Why this first

A widget is the highest-leverage first post-launch feature for a *daily-habit* app: it drags the streak onto the Home Screen where the user already looks, which is a direct retention lever, and it's inherently **screenshot-worthy** — the same growth mechanic that made MeAgain's "capybara widget" go viral. Every user who screenshots their streak is free distribution. Moderate effort, high fit.

## What it shows

| Family | Content |
| --- | --- |
| `systemSmall` (Home) | 🔥 flame + big streak number, "day streak", and a status pill: **Taken today** (white pill) or **Take today's pill** (translucent). Full brand teal→mint gradient. |
| `accessoryCircular` (Lock) | flame + streak number, accent-tinted. |
| `accessoryRectangular` (Lock) | flame + "N day streak" + today's status line. |

Tapping the widget deep-links into the app (default widget URL → opens GLPill).

## How it works (architecture)

The widget is a separate **WidgetKit app-extension target** (`GLPillWidget`), embedded in the app. It never touches SwiftData or CloudKit directly — that would be heavy and fragile in an extension. Instead:

1. The app and the widget share an **App Group** container: `group.com.ayushgupta.glpill` (entitlement on both targets).
2. The app writes a tiny `GLPillWidgetSnapshot` (streak, doseTakenToday, med name, dose mg) into the App Group's shared `UserDefaults` — see `App/Shared/GLPillWidgetShared.swift` (compiled into both targets).
3. `WidgetSnapshotBuilder` (app target) builds that snapshot from the store and calls `GLPillWidgetBridge.save(...)`, which persists it and calls `WidgetCenter.reloadAllTimelines()`.
4. The widget's `TimelineProvider` reads the snapshot via `GLPillWidgetBridge.load()` and refreshes just after midnight so "taken today" resets and the streak re-evaluates.

Snapshot refresh points in the app:
- On launch (`GLPillApp` `.task`).
- After each dose log (`TodayStore.logDose`).

If the App Group isn't provisioned (e.g. unsigned build), `UserDefaults(suiteName:)` returns nil and the widget falls back to a neutral empty state — never crashes.

## Files

- `App/Shared/GLPillWidgetShared.swift` — `GLPillWidgetSnapshot` + `GLPillWidgetBridge` (shared by both targets).
- `App/Sources/Core/Widget/WidgetSnapshotBuilder.swift` — builds the snapshot from the store (app target).
- `App/Widget/GLPillWidget.swift` — the extension: provider, entry, SwiftUI views, `@main` bundle.
- `App/Widget/Info.plist` — `NSExtensionPointIdentifier = com.apple.widgetkit-extension` + standard bundle keys.
- `App/Widget/GLPillWidget.entitlements` — App Group only.
- `App/Resources/GLPill.entitlements` — App Group added alongside the existing iCloud/CloudKit entitlements.
- Tests: `App/Tests/WidgetSnapshotTests.swift` (streak/taken-today logic + Codable round-trip).

## Provisioning note (device / App Store)

The App Group `group.com.ayushgupta.glpill` and the widget's bundle ID `com.ayushgupta.glpill.widget` need to exist under the paid team. Automatic signing in Xcode registers them on first device build; confirm the App Group is enabled for **both** the app and the widget App IDs in the Developer portal before submitting.

## Follow-ups (not in this build)

- Deep-link the "Take today's pill" tap straight to the log action (interactive widget / AppIntent) rather than just opening the app.
- Live Activity / Dynamic Island for the Rybelsus 30-minute eat timer (already in BACKLOG.md).
