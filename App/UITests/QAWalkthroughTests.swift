import XCTest

/// A screenshot walkthrough of the pill co-pilot experience, used for visual QA.
/// Captures every key screen as a keepAlways attachment so the images can be
/// pulled from the result bundle. Navigation mirrors the passing onboarding test.
final class QAWalkthroughTests: XCTestCase {
    @MainActor
    func testWalkthroughCapturesEveryScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetData", "-disableCloudKit"]
        app.launch()

        // 0 — Welcome
        let getStarted = app.buttons["Get started"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 10))
        shot(app, "01-welcome")
        getStarted.tap()

        // 1 — Stage
        app.staticTexts["I'm about to start"].tap()
        shot(app, "02-stage")
        tapContinue(app)

        // 2 — Medication (shows the pill-first list incl. Wegovy pill)
        let rybelsus = app.staticTexts["Rybelsus (semaglutide)"]
        XCTAssertTrue(rybelsus.waitForExistence(timeout: 5))
        shot(app, "03-medication")
        rybelsus.tap()
        tapContinue(app)

        // 3 — Dose ladder (Rybelsus 3/7/14)
        let firstDose = app.staticTexts["3 mg"]
        XCTAssertTrue(firstDose.waitForExistence(timeout: 5))
        shot(app, "04-dose-ladder")
        firstDose.tap()
        tapContinue(app)

        // 4 — Daily time
        shot(app, "05-daily-time")
        tapContinue(app)

        // 5 — Wait window
        let wait = app.staticTexts["30 minutes"]
        XCTAssertTrue(wait.waitForExistence(timeout: 5))
        shot(app, "06-wait-window")
        wait.tap()
        tapContinue(app)

        // 6 — Morning meds: add one so the Today sequence shows real meds
        let field = app.textFields["Add a medication"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Levothyroxine")
        app.buttons["Add"].tap()
        shot(app, "07-morning-meds")
        tapContinue(app)

        // 7 — Concerns
        let nausea = app.staticTexts["Nausea"]
        XCTAssertTrue(nausea.waitForExistence(timeout: 5))
        shot(app, "08-concerns")
        nausea.tap()
        tapContinue(app)

        // 8 — Goals
        shot(app, "09-goals")
        tapContinue(app)

        // 9 — Reminder style
        let reminder = app.staticTexts["Just the pill reminder"]
        XCTAssertTrue(reminder.waitForExistence(timeout: 5))
        shot(app, "10-reminder-style")
        reminder.tap()
        tapContinue(app)

        // 10 — Plan reveal
        let startDay = app.buttons["Start day 1"]
        XCTAssertTrue(startDay.waitForExistence(timeout: 5))
        shot(app, "11-plan-reveal")
        startDay.tap()
        allowNotificationsIfAsked()

        // Today — before logging
        let today = app.tabBars.buttons["Today"]
        XCTAssertTrue(today.waitForExistence(timeout: 10))
        shot(app, "12-today-before-dose")

        // Log today's pill → morning sequence + eat timer + med level appear
        let take = app.buttons["Take today's pill"]
        if take.waitForExistence(timeout: 5) { take.tap() }
        sleep(1)
        shot(app, "13-today-after-dose")

        // Medication-level full graph
        let medLevel = app.staticTexts["Medication level"]
        if medLevel.waitForExistence(timeout: 5) {
            medLevel.tap()
            sleep(1)
            shot(app, "14-medication-level-graph")
            if app.navigationBars.buttons.firstMatch.exists { app.navigationBars.buttons.firstMatch.tap() }
        }

        // Central Log sheet via the FAB
        let fab = app.buttons["Log something"]
        if fab.waitForExistence(timeout: 5) {
            fab.tap()
            sleep(1)
            shot(app, "15-log-sheet")
            // Open the weigh-in sheet to capture the kg/lb toggle
            let weightRow = app.buttons["Weight"]
            if weightRow.waitForExistence(timeout: 3) {
                weightRow.tap()
                sleep(1)
                shot(app, "17-weighin-units")
                if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
            } else if app.navigationBars.buttons.firstMatch.exists {
                app.swipeDown()
            }
        }

        // Scroll Today to the intake card to capture the filling vessels + steppers
        sleep(1)
        app.swipeUp()
        app.swipeUp()
        sleep(1)
        shot(app, "16-intake-vessels")
    }

    @MainActor private func tapContinue(_ app: XCUIApplication) {
        let cont = app.buttons["Continue"]
        XCTAssertTrue(cont.waitForExistence(timeout: 5))
        cont.tap()
    }

    @MainActor private func allowNotificationsIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }
    }

    @MainActor private func shot(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}
