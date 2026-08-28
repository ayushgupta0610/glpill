import XCTest

/// Captures the five App Store screenshots from the REAL running app.
///
/// Guideline 2.3.3 rejected the previous set because they were composed marketing
/// images from `ScreenshotExporter` (headline + floating cards on a gradient, no
/// status bar, no tab bar). Apple: "Marketing or promotional materials that do not
/// reflect the UI of the app are not appropriate for screenshots."
///
/// These are genuine device screenshots — real navigation, real tab bar, real data
/// from `DemoDataSeeder`. Run with:
///
///     xcrun simctl status_bar <sim> override --time "9:41" --batteryState charged \
///       --batteryLevel 100 --cellularBars 4 --wifiBars 3
///     xcodebuild test -project GLPill.xcodeproj -scheme GLPill \
///       -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
///       -only-testing:GLPillUITests/AppStoreShotsTests -resultBundlePath shots.xcresult
///     xcrun xcresulttool export attachments --path shots.xcresult --output-path out/
final class AppStoreShotsTests: XCTestCase {
    @MainActor
    func testCaptureAppStoreScreenshots() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetData", "-disableCloudKit", "-seedDemoData"]
        app.launch()

        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.buttons["Today"].waitForExistence(timeout: 15), "seeded launch should land on Today")
        allowNotificationsIfAsked()

        // 1 — Today: streak, current titration step, morning sequence
        shot("01-today")

        // 2 — Rybelsus empty-stomach timer, counting down live.
        //     Undo the seeded morning dose, then re-log it so the 30-minute window starts now.
        if app.buttons["Undo"].waitForExistence(timeout: 3) {
            app.buttons["Undo"].tap()
            let take = app.buttons["Take today's pill"]
            if take.waitForExistence(timeout: 5) {
                take.tap()
                sleep(2)
            }
        }
        shot("02-timer")

        // 3 — Progress: weight trend, projection, milestones
        tabs.buttons["Progress"].tap()
        sleep(2)
        shot("03-progress")

        // 4 — History: calendar of logged days
        tabs.buttons["History"].tap()
        sleep(2)
        shot("04-history")

        // 5 — Report: the doctor-ready 4-week summary
        tabs.buttons["Report"].tap()
        sleep(2)
        shot("05-report")

        // 6 — Settings › Privacy policy: the free + private + own-iCloud claim, on a
        //     real screen. glpillapp.com leads with "The free, private tracker" and the
        //     App Store description says the same; this is the in-app screen behind it.
        //     The copy lives in SettingsView.PrivacyPolicyView, a NavigationLink
        //     destination — so navigate into it rather than scrolling Settings.
        tabs.buttons["Settings"].tap()
        sleep(2)
        let privacyLink = app.buttons["Privacy policy"]
        if !privacyLink.waitForExistence(timeout: 5) { app.swipeUp(); sleep(1) }
        XCTAssertTrue(privacyLink.waitForExistence(timeout: 5), "Privacy policy row not reachable")
        privacyLink.tap()
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'GLPill is free'")
        ).firstMatch.waitForExistence(timeout: 5), "Privacy summary copy did not load")
        sleep(1)
        shot("06-privacy")
    }

    @MainActor private func allowNotificationsIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }
    }

    /// Full-device capture (status bar included), not just the app window.
    @MainActor private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
