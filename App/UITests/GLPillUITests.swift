import XCTest

final class GLPillUITests: XCTestCase {
    @MainActor
    func testOnboardingLeadsToPaywall() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetData", "-disableCloudKit"]
        app.launch()

        completeOnboarding(app)

        // The auto-renew disclaimer is our own view and renders even while
        // SubscriptionStoreView is still loading products.
        let disclaimer = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Auto-renews'")).firstMatch
        XCTAssertTrue(disclaimer.waitForExistence(timeout: 10))
        attach(app, name: "paywall")
    }

    @MainActor
    func testUnlockedFlowLogsDoseAndVisitsTabs() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetData", "-uiTestUnlocked", "-disableCloudKit"]
        app.launch()

        completeOnboarding(app)

        let takeButton = app.buttons["Take today's pill"]
        XCTAssertTrue(takeButton.waitForExistence(timeout: 10))
        attach(app, name: "today-before-dose")

        takeButton.tap()
        // Rybelsus requires an empty stomach, so logging the dose starts the
        // 30-min eat-timer window rather than showing a plain "Taken at" state.
        let eatTimer = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'You can eat'")).firstMatch
        XCTAssertTrue(eatTimer.waitForExistence(timeout: 5))
        attach(app, name: "today-after-dose")

        app.tabBars.buttons["Progress"].tap()
        attach(app, name: "progress")
        app.tabBars.buttons["History"].tap()
        attach(app, name: "history")
        app.tabBars.buttons["Report"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Adherence'")).firstMatch.waitForExistence(timeout: 5))
        attach(app, name: "report")
        app.tabBars.buttons["Settings"].tap()
        attach(app, name: "settings")
    }

    @MainActor
    private func completeOnboarding(_ app: XCUIApplication) {
        let getStarted = app.buttons["Get started"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 10))
        getStarted.tap()

        // Medication step — pick Rybelsus to exercise the eat-timer path
        let rybelsus = app.staticTexts["Rybelsus (semaglutide)"]
        XCTAssertTrue(rybelsus.waitForExistence(timeout: 5))
        rybelsus.tap()
        app.buttons["Continue"].tap()

        // Titration step — accept the default plan
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5))
        app.buttons["Continue"].tap()

        // Weight step — typing depends on the simulator keyboard being attachable,
        // so fall back to skipping the (optional) weight if focus never arrives.
        let weightField = app.textFields.firstMatch
        XCTAssertTrue(weightField.waitForExistence(timeout: 5))
        weightField.tap()
        if !app.keyboards.element.waitForExistence(timeout: 2) {
            weightField.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        if app.keyboards.element.waitForExistence(timeout: 2) {
            weightField.typeText("90")
        }
        app.buttons["Continue"].tap()

        // Morning meds step — optional, skip it in tests
        let skipMorningMeds = app.buttons["Skip for now"]
        XCTAssertTrue(skipMorningMeds.waitForExistence(timeout: 5))
        skipMorningMeds.tap()

        // Reminder step
        let finish = app.buttons["Finish setup"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()

        allowNotificationsIfAsked()
    }

    @MainActor
    private func allowNotificationsIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) {
            allow.tap()
        }
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
