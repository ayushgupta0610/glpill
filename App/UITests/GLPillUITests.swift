import XCTest

final class GLPillUITests: XCTestCase {
    @MainActor
    func testOnboardingLeadsToTodayTab() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetData", "-disableCloudKit"]
        app.launch()

        completeOnboarding(app)

        // Freemium: the app is free, so completing onboarding lands on the Today
        // tab (MainTabView) — not a hard paywall.
        let today = app.tabBars.buttons["Today"]
        XCTAssertTrue(today.waitForExistence(timeout: 10))
        attach(app, name: "today-tab")
    }

    @MainActor
    func testUnlockedFlowLogsDoseAndVisitsTabs() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetData", "-disableCloudKit"]
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
        // 0 — Welcome
        let getStarted = app.buttons["Get started"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 10))
        getStarted.tap()

        // 1 — Stage: pick an option, then continue
        let stageOption = app.staticTexts["I'm about to start"]
        XCTAssertTrue(stageOption.waitForExistence(timeout: 5))
        stageOption.tap()
        tapContinue(app)

        // 2 — Medication: pick Rybelsus to exercise the empty-stomach / eat-timer path
        let rybelsus = app.staticTexts["Rybelsus (semaglutide)"]
        XCTAssertTrue(rybelsus.waitForExistence(timeout: 5))
        rybelsus.tap()
        tapContinue(app)

        // 3 — Dose ladder: pick the first ladder dose
        let firstDose = app.staticTexts["3 mg"]
        XCTAssertTrue(firstDose.waitForExistence(timeout: 5))
        firstDose.tap()
        tapContinue(app)

        // 4 — Daily time: accept the default time
        tapContinue(app)

        // 5 — Wait window (Rybelsus requires empty stomach, so this screen shows)
        let waitOption = app.staticTexts["30 minutes"]
        XCTAssertTrue(waitOption.waitForExistence(timeout: 5))
        waitOption.tap()
        tapContinue(app)

        // 6 — Morning meds: optional, skip it in tests
        let skipMorningMeds = app.buttons["Skip for now"]
        XCTAssertTrue(skipMorningMeds.waitForExistence(timeout: 5))
        skipMorningMeds.tap()

        // 7 — Concerns: optional multi-select, just continue
        tapContinue(app)

        // 8 — Goals: optional multi-select, just continue
        tapContinue(app)

        // 9 — Reminder style: pick an option, then continue
        let reminderOption = app.staticTexts["Just the pill reminder"]
        XCTAssertTrue(reminderOption.waitForExistence(timeout: 5))
        reminderOption.tap()
        tapContinue(app)

        // 10 — Plan reveal
        let startDay = app.buttons["Start day 1"]
        XCTAssertTrue(startDay.waitForExistence(timeout: 5))
        startDay.tap()

        allowNotificationsIfAsked()
    }

    @MainActor
    private func tapContinue(_ app: XCUIApplication) {
        let cont = app.buttons["Continue"]
        XCTAssertTrue(cont.waitForExistence(timeout: 5))
        cont.tap()
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
