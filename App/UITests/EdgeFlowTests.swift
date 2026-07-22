import XCTest

/// Runtime bug-hunt round 2 — drives edge-case user flows on the simulator and
/// asserts real UI state. Each test onboards fresh (`-resetData -disableCloudKit`)
/// via a parameterized helper, then exercises one edge flow. Screenshots are
/// attached at key points for visual confirmation.
final class EdgeFlowTests: XCTestCase {

    // MARK: Onboarding driver

    /// Options for the parameterized onboarding walkthrough.
    struct OnboardConfig {
        var drug: String = "Foundayo (orforglipron)"   // medication row label
        var pickDose: Bool = true                        // false = "Not sure"
        var waitWindow: String = "30 minutes"            // only used on empty-stomach path
        var morningMeds: [String] = []
        var goals: [String] = []                         // GoalsStep ids' labels to tap
        var reminderStyle: String = "Just the pill reminder"
    }

    @MainActor
    private func launch(_ app: XCUIApplication) {
        app.launchArguments = ["-resetData", "-disableCloudKit"]
        app.launch()
    }

    /// Runs onboarding to the Today tab. Returns after Today is visible.
    @MainActor
    private func completeOnboarding(_ app: XCUIApplication, _ config: OnboardConfig = OnboardConfig()) {
        let getStarted = app.buttons["Get started"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 15), "Welcome screen never appeared")
        getStarted.tap()

        // Stage
        app.staticTexts["I'm about to start"].tap()
        tapContinue(app)

        // Medication
        let drugRow = app.staticTexts[config.drug]
        XCTAssertTrue(drugRow.waitForExistence(timeout: 5), "Medication '\(config.drug)' row missing")
        drugRow.tap()
        tapContinue(app)

        // Dose ladder
        let notSure = app.staticTexts["Not sure"]
        XCTAssertTrue(notSure.waitForExistence(timeout: 5), "Dose step missing")
        if config.pickDose {
            // Tap the lowest ladder dose (first "N mg" row).
            let firstDose = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH ' mg'")).firstMatch
            XCTAssertTrue(firstDose.waitForExistence(timeout: 5))
            firstDose.tap()
            tapContinue(app)
        } else {
            notSure.tap()   // "Not sure" advances immediately
        }

        // Daily time (empty-stomach path only shows Wait window after this)
        // Continue through daily time.
        tapContinue(app)

        let requiresWindow = config.drug.contains("Rybelsus") || config.drug.contains("Wegovy")
        if requiresWindow {
            let wait = app.staticTexts[config.waitWindow]
            XCTAssertTrue(wait.waitForExistence(timeout: 5), "Wait-window step missing for empty-stomach drug")
            wait.tap()
            tapContinue(app)
        }

        // Morning meds
        let field = app.textFields["Add a medication"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Morning-meds step missing")
        for med in config.morningMeds {
            field.tap()
            field.typeText(med)
            app.buttons["Add"].tap()
        }
        // The morning-meds CTA is "Skip for now" when empty, "Continue" once meds exist.
        let morningCTA = config.morningMeds.isEmpty ? app.buttons["Skip for now"] : app.buttons["Continue"]
        XCTAssertTrue(morningCTA.waitForExistence(timeout: 5), "Morning-meds CTA missing")
        morningCTA.tap()

        // Concerns
        let nausea = app.staticTexts["Nausea"]
        XCTAssertTrue(nausea.waitForExistence(timeout: 5), "Concerns step missing")
        nausea.tap()
        tapContinue(app)

        // Goals
        XCTAssertTrue(app.staticTexts["What should this app help with?"].waitForExistence(timeout: 5))
        for goal in config.goals {
            let row = app.staticTexts[goal]
            if row.waitForExistence(timeout: 3) { row.tap() }
        }
        tapContinue(app)

        // Reminder style
        let reminder = app.staticTexts[config.reminderStyle]
        XCTAssertTrue(reminder.waitForExistence(timeout: 5), "Reminder-style step missing")
        reminder.tap()
        tapContinue(app)

        // Plan reveal
        let startDay = app.buttons["Start day 1"]
        XCTAssertTrue(startDay.waitForExistence(timeout: 5), "Plan reveal missing")
        startDay.tap()
        allowNotificationsIfAsked()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 15), "Today tab never appeared")
    }

    // MARK: - Flow 1: Foundayo path (no empty-stomach window)

    @MainActor
    func testFoundayoNoWaitWindowAndAnyTimeMeds() {
        let app = XCUIApplication()
        launch(app)
        completeOnboarding(app, OnboardConfig(drug: "Foundayo (orforglipron)", morningMeds: ["Levothyroxine"]))

        // Ritual card should say "No timing rules", NOT the empty-stomach line.
        XCTAssertTrue(app.staticTexts["No timing rules — take it with or without food."].waitForExistence(timeout: 5),
                      "Foundayo should show the no-timing-rules line")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Empty stomach'")).firstMatch.exists,
                       "Foundayo must NOT show an empty-stomach instruction")
        shot(app, "F1-foundayo-before-dose")

        // Log the pill.
        let take = app.buttons["Take today's pill"]
        XCTAssertTrue(take.waitForExistence(timeout: 5))
        take.tap()
        sleep(1)
        shot(app, "F1-foundayo-after-dose")

        // No eat timer should appear (no "you can eat" window). The clear-state
        // message should be the no-window variant.
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Wait' AND label CONTAINS 'min'")).firstMatch.exists,
                       "Foundayo should show NO eat timer after logging")
        // Morning-meds "any time" framing.
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'any time'")).firstMatch.waitForExistence(timeout: 5),
                      "Foundayo morning-meds should read 'any time'")
    }

    // MARK: - Flow 2: "Not sure" dose

    @MainActor
    func testNotSureDose() {
        let app = XCUIApplication()
        launch(app)
        completeOnboarding(app, OnboardConfig(drug: "Foundayo (orforglipron)", pickDose: false))

        // Dose subtitle should read the not-set copy.
        XCTAssertTrue(app.staticTexts["Dose not set — add in Settings"].waitForExistence(timeout: 5),
                      "Not-sure dose should show 'Dose not set' subtitle")
        shot(app, "F2-notsure-today")

        // Medication-level card should show the empty/building state, not a fabricated steady line.
        let medLevelCard = app.staticTexts["Medication level"]
        XCTAssertTrue(medLevelCard.waitForExistence(timeout: 5))
        // Navigate into the full graph — must not crash.
        medLevelCard.tap()
        sleep(1)
        shot(app, "F2-notsure-medlevel-graph")
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5) ||
                      app.navigationBars.buttons.firstMatch.exists,
                      "App survived navigating to med-level graph with no dose")
        if app.navigationBars.buttons.firstMatch.exists { app.navigationBars.buttons.firstMatch.tap() }
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
    }

    // MARK: - Flow 3: Log via sheet vs hero + undo + re-log

    @MainActor
    func testLogSheetAndHeroAndUndo() {
        let app = XCUIApplication()
        launch(app)
        completeOnboarding(app, OnboardConfig(drug: "Foundayo (orforglipron)"))

        // Log via the hero button.
        let take = app.buttons["Take today's pill"]
        XCTAssertTrue(take.waitForExistence(timeout: 5))
        take.tap()
        sleep(1)
        shot(app, "F3-after-hero-log")

        // Streak should now show.
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'day streak' OR label CONTAINS 'Longest'")).firstMatch.waitForExistence(timeout: 5),
                      "Streak did not appear after logging")

        // Undo the dose from the ritual card.
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "Undo button missing after dose")
        undo.tap()
        sleep(1)
        XCTAssertTrue(app.buttons["Take today's pill"].waitForExistence(timeout: 5),
                      "Ritual did not return to not-taken after undo")
        shot(app, "F3-after-undo")

        // Re-log via the FAB Log sheet.
        let fab = app.buttons["Log something"]
        XCTAssertTrue(fab.waitForExistence(timeout: 5))
        fab.tap()
        let tookPill = app.buttons["Took my pill"]
        XCTAssertTrue(tookPill.waitForExistence(timeout: 5), "Log sheet 'Took my pill' missing")
        tookPill.tap()
        sleep(1)
        shot(app, "F3-after-sheet-relog")
        // Ritual should be logged again (Undo available, no crash).
        XCTAssertTrue(app.buttons["Undo"].waitForExistence(timeout: 5),
                      "Re-log via sheet did not register")
    }

    // MARK: - Flow 4: Intake stress

    @MainActor
    func testIntakeStress() {
        let app = XCUIApplication()
        launch(app)
        completeOnboarding(app, OnboardConfig(drug: "Foundayo (orforglipron)"))

        // Scroll to intake card.
        app.swipeUp(); app.swipeUp(); sleep(1)

        // Rapid ± taps on protein.
        let plus = app.buttons["Add 5 g"]
        XCTAssertTrue(plus.waitForExistence(timeout: 5), "Protein + button missing")
        for _ in 0..<8 { plus.tap() }
        let minus = app.buttons["Subtract 5 g"]
        for _ in 0..<3 { minus.tap() }
        sleep(1)
        shot(app, "F4-after-rapid-taps")

        // Undo snackbar (from a quick add) — trigger via log sheet water then undo.
        // First open tap-to-type on protein total.
        let proteinTotal = app.buttons.matching(NSPredicate(format: "label CONTAINS 'grams of protein'")).firstMatch
        XCTAssertTrue(proteinTotal.waitForExistence(timeout: 5), "Protein total tap target missing")

        // Huge value.
        proteinTotal.tap()
        typeIntoAlert(app, "999999999", set: true)
        sleep(1)
        // Value should be clamped/rejected — not a crash. Assert app alive.
        XCTAssertTrue(app.tabBars.buttons["Today"].exists, "App crashed on huge protein value")
        shot(app, "F4-after-huge-value")

        // Negative value.
        proteinTotal.tap()
        typeIntoAlert(app, "-5", set: true)
        sleep(1)
        XCTAssertTrue(app.tabBars.buttons["Today"].exists, "App crashed on negative protein value")

        // Decimal value.
        proteinTotal.tap()
        typeIntoAlert(app, "12.7", set: true)
        sleep(1)
        XCTAssertTrue(app.tabBars.buttons["Today"].exists, "App crashed on decimal protein value")
        shot(app, "F4-after-decimal")
    }

    // MARK: - Flow 5: Weigh-in double-save + outlier

    @MainActor
    func testWeighInDoubleSaveAndOutlier() {
        let app = XCUIApplication()
        launch(app)
        completeOnboarding(app, OnboardConfig(drug: "Foundayo (orforglipron)", goals: ["See my weight trend"]))

        // Open weigh-in from FAB.
        let fab = app.buttons["Log something"]
        XCTAssertTrue(fab.waitForExistence(timeout: 5))
        fab.tap()
        let weightRow = app.buttons["Weight"]
        XCTAssertTrue(weightRow.waitForExistence(timeout: 5))
        weightRow.tap()

        XCTAssertTrue(app.navigationBars["Add weigh-in"].waitForExistence(timeout: 5), "Weigh-in sheet missing")
        // Toggle kg/lb.
        if app.buttons["kg"].exists { app.buttons["kg"].tap() }
        // Enter a value.
        let field = app.textFields["0"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("80")
        // Double-tap Save fast.
        let save = app.buttons["Save"]
        save.tap()
        if save.exists { save.tap() }   // second tap should be a no-op (isSaving guard)
        sleep(1)
        shot(app, "F5-after-doublesave")

        // Go to Progress tab and count entries — should be exactly ONE 80 kg row.
        app.tabBars.buttons["Progress"].tap()
        sleep(1)
        shot(app, "F5-progress-entries")
        // A double-tapped Save must NOT create two weigh-in rows. The weigh-in list
        // renders one row per entry showing "80 kg"; the stats "Current" card also
        // shows it once. So a single entry => at most 2 occurrences; a duplicate => 3+.
        let eightyKg = app.staticTexts.matching(NSPredicate(format: "label == '80 kg'")).count
        XCTAssertLessThanOrEqual(eightyKg, 2,
                                 "Double-tap Save created a duplicate weigh-in (found \(eightyKg) '80 kg' labels)")

        // Add an outlier — open weigh-in again with a wildly different value.
        app.tabBars.buttons["Today"].tap()
        let fab2 = app.buttons["Log something"]
        XCTAssertTrue(fab2.waitForExistence(timeout: 5))
        fab2.tap()
        app.buttons["Weight"].tap()
        XCTAssertTrue(app.navigationBars["Add weigh-in"].waitForExistence(timeout: 5))
        if app.buttons["kg"].exists { app.buttons["kg"].tap() }
        let field2 = app.textFields["0"]
        field2.tap()
        field2.typeText("300")
        app.buttons["Save"].tap()
        sleep(1)
        // Outlier confirm alert should appear.
        let outlierAlert = app.staticTexts["Double-check this weigh-in"]
        XCTAssertTrue(outlierAlert.waitForExistence(timeout: 5), "Outlier confirm alert did not appear for 300 kg jump")
        shot(app, "F5-outlier-alert")
        // Dismiss the outlier alert specifically (a "Cancel" also exists on the sheet toolbar).
        if app.alerts.buttons["Cancel"].exists { app.alerts.buttons["Cancel"].tap() }
    }

    // MARK: - Flow 6: Goal shortcut cards → tab switch (no double nav / no push)

    @MainActor
    func testGoalShortcutsSwitchTabs() {
        let app = XCUIApplication()
        launch(app)
        completeOnboarding(app, OnboardConfig(drug: "Foundayo (orforglipron)",
                                              goals: ["See my weight trend", "Keep records for my doctor"]))

        // Weight shortcut card.
        let weightCard = app.staticTexts["Weight"].firstMatch
        XCTAssertTrue(weightCard.waitForExistence(timeout: 5), "Weight shortcut card missing")
        weightCard.tap()
        sleep(1)
        shot(app, "F6-after-weight-shortcut")
        // Should switch to Progress tab (selected), NOT push a second nav bar.
        XCTAssertTrue(app.tabBars.buttons["Progress"].isSelected,
                      "Weight shortcut should switch to Progress tab")
        XCTAssertEqual(app.navigationBars.count, 1,
                       "Progress screen shows a doubled navigation bar (nested NavigationStack)")

        // Back to Today, tap Report shortcut.
        app.tabBars.buttons["Today"].tap()
        let reportCard = app.staticTexts["Doctor-ready report"]
        XCTAssertTrue(reportCard.waitForExistence(timeout: 5), "Report shortcut card missing")
        reportCard.tap()
        sleep(1)
        shot(app, "F6-after-report-shortcut")
        XCTAssertTrue(app.tabBars.buttons["Report"].isSelected,
                      "Report shortcut should switch to Report tab")
        XCTAssertEqual(app.navigationBars.count, 1,
                       "Report screen shows a doubled navigation bar (nested NavigationStack)")
    }

    // MARK: - Flow 7: Paywall dismiss

    @MainActor
    func testPaywallDismiss() {
        let app = XCUIApplication()
        launch(app)
        completeOnboarding(app, OnboardConfig(drug: "Foundayo (orforglipron)"))

        // Premium is gated on the doctor-report export: a free user tapping
        // "Export report" on the Report tab gets the paywall.
        app.tabBars.buttons["Report"].tap()
        // Free user's gated control: label reads "Export report, Premium".
        let exportButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Export report'")).firstMatch
        XCTAssertTrue(exportButton.waitForExistence(timeout: 5), "Export report (premium) button missing")
        exportButton.tap()
        sleep(1)
        shot(app, "F7-paywall")
        // Paywall should be up.
        XCTAssertTrue(app.staticTexts["Unlock GLPill Premium"].waitForExistence(timeout: 5),
                      "Paywall did not present from the Export report button")
        // Close control.
        let close = app.buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "Paywall Close control missing")
        close.tap()
        sleep(1)
        XCTAssertFalse(app.staticTexts["Unlock GLPill Premium"].exists, "Paywall did not dismiss")
        shot(app, "F7-after-close")
    }

    // MARK: - Flow 8: Many / long morning meds

    @MainActor
    func testManyLongMorningMeds() {
        let app = XCUIApplication()
        launch(app)
        let longName = "Levothyroxine Sodium Extended Release Supercalifragilistic Tablet 137mcg"
        completeOnboarding(app, OnboardConfig(
            drug: "Rybelsus (semaglutide)",
            morningMeds: ["Metformin", "Lisinopril", "Atorvastatin", longName]
        ))

        // Today morning-sequence card should render without crashing.
        XCTAssertTrue(app.staticTexts["Your morning sequence"].waitForExistence(timeout: 5),
                      "Morning sequence card missing with many meds")
        shot(app, "F8-many-meds-today")
        XCTAssertTrue(app.tabBars.buttons["Today"].exists, "App crashed rendering many/long morning meds")
    }

    // MARK: - Flow 8b: Rybelsus eat-timer window + undo mid-window

    @MainActor
    func testRybelsusEatTimerAndUndoMidWindow() {
        let app = XCUIApplication()
        launch(app)
        completeOnboarding(app, OnboardConfig(drug: "Rybelsus (semaglutide)", morningMeds: ["Levothyroxine"]))

        // Empty-stomach instruction should be present pre-dose.
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Empty stomach'")).firstMatch.waitForExistence(timeout: 5),
                      "Rybelsus should show empty-stomach instruction")

        let take = app.buttons["Take today's pill"]
        XCTAssertTrue(take.waitForExistence(timeout: 5))
        take.tap()
        sleep(1)
        shot(app, "F8b-window-running")

        // The eat-timer window should be running; morning meds should read "after HH:MM".
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Other morning meds' AND label CONTAINS 'after'")).firstMatch.waitForExistence(timeout: 5),
                      "Running window should show 'Other morning meds — after <time>'")

        // Undo mid-window.
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "Undo missing during running window")
        undo.tap()
        sleep(1)
        shot(app, "F8b-after-undo-midwindow")

        // Should return to not-taken; the timer must be gone, empty-stomach line back.
        XCTAssertTrue(app.buttons["Take today's pill"].waitForExistence(timeout: 5),
                      "Undo mid-window did not return the ritual to not-taken")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Other morning meds' AND label CONTAINS 'after'")).firstMatch.exists,
                       "Eat-timer/morning-meds 'after' text lingered after undo (stuck window)")
    }

    // MARK: - Flow 9: Settings editors + reminder changes

    @MainActor
    func testSettingsEditorsAndReminders() {
        let app = XCUIApplication()
        launch(app)
        completeOnboarding(app, OnboardConfig(drug: "Rybelsus (semaglutide)", morningMeds: ["Levothyroxine"]))

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        // Change reminder style through each value.
        let reminderPicker = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Reminders'")).firstMatch
        // Reminder style is a segmented/menu Picker labeled "Reminders". Try tapping options directly.
        for style in ["Off", "Pill only", "Pill + window clear"] {
            let opt = app.buttons[style].firstMatch
            if opt.waitForExistence(timeout: 2) { opt.tap(); sleep(1) }
        }
        _ = reminderPicker
        shot(app, "F9-settings-reminders")
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists, "App crashed toggling reminder styles")

        // Open each editor.
        for editor in ["Medication", "Dose plan", "Morning meds"] {
            let link = app.buttons[editor].firstMatch
            if link.waitForExistence(timeout: 3) {
                link.tap()
                sleep(1)
                shot(app, "F9-editor-\(editor.replacingOccurrences(of: " ", with: "-"))")
                XCTAssertTrue(app.tabBars.buttons["Settings"].exists || app.navigationBars.buttons.firstMatch.exists,
                              "App crashed opening \(editor) editor")
                if app.navigationBars.buttons.firstMatch.exists { app.navigationBars.buttons.firstMatch.tap() }
                sleep(1)
            }
        }
    }

    // MARK: - Flow 10: Rapid navigation

    @MainActor
    func testRapidNavigation() {
        let app = XCUIApplication()
        launch(app)
        completeOnboarding(app, OnboardConfig(drug: "Foundayo (orforglipron)"))

        let tabs = ["Progress", "History", "Report", "Settings", "Today"]
        for _ in 0..<3 {
            for tab in tabs {
                let b = app.tabBars.buttons[tab]
                if b.exists { b.tap() }
            }
        }
        // Rapidly open/close the log sheet.
        app.tabBars.buttons["Today"].tap()
        for _ in 0..<3 {
            let fab = app.buttons["Log something"]
            if fab.waitForExistence(timeout: 3) {
                fab.tap()
                if app.buttons["Took my pill"].waitForExistence(timeout: 2) {
                    app.swipeDown()
                }
            }
        }
        sleep(1)
        shot(app, "F10-after-rapid-nav")
        XCTAssertTrue(app.tabBars.buttons["Today"].exists, "App crashed under rapid navigation")
    }

    // MARK: - Helpers

    @MainActor private func tapContinue(_ app: XCUIApplication) {
        let cont = app.buttons["Continue"]
        XCTAssertTrue(cont.waitForExistence(timeout: 5), "Continue button missing")
        cont.tap()
    }

    /// Types text into the currently-presented intake alert and taps Set (or Cancel).
    @MainActor private func typeIntoAlert(_ app: XCUIApplication, _ text: String, set: Bool) {
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Intake alert did not appear")
        let tf = alert.textFields.firstMatch
        if tf.waitForExistence(timeout: 3) {
            tf.tap()
            tf.typeText(text)
        }
        if set {
            if alert.buttons["Set"].exists { alert.buttons["Set"].tap() }
        }
        // If the alert stayed open (invalid input), dismiss it so the test can continue.
        if app.alerts.firstMatch.waitForExistence(timeout: 1),
           app.alerts.buttons["Cancel"].exists {
            app.alerts.buttons["Cancel"].tap()
        }
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
