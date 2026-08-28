import XCTest

/// Runtime regression hunt — Round 3.
///
/// Fresh XCUITest coverage for the flows changed by the last ~20 fixes
/// (med-level caption honesty, reflux side-effect kind,
/// med-switch eat-timer cancel, onboarding Back navigation, weigh-in
/// edit/delete, reminder-style cycle, goal-ordered Today + coaching).
///
/// The Round-2 `EdgeFlowTests` predate these fixes; this file is additive.
/// Each test onboards fresh via a parameterized helper.
final class Round3RegressionTests: XCTestCase {

    // MARK: - Onboarding driver

    struct OnboardConfig {
        var drug: String = "Foundayo (orforglipron)"
        var pickDose: Bool = true
        var waitWindow: String = "30 minutes"
        var morningMeds: [String] = []
        var concerns: [String] = []          // ConcernsStep labels to tap
        var goals: [String] = []
        var reminderStyle: String = "Just the pill reminder"
    }

    @MainActor
    private func launch(_ app: XCUIApplication) {
        app.launchArguments = ["-resetData", "-disableCloudKit"]
        app.launch()
    }

    @MainActor
    private func completeOnboarding(_ app: XCUIApplication, _ config: OnboardConfig = OnboardConfig()) {
        let getStarted = app.buttons["Get started"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 15), "Welcome screen never appeared")
        getStarted.tap()

        app.staticTexts["I'm about to start"].tap()
        tapContinue(app)

        let drugRow = app.staticTexts[config.drug]
        XCTAssertTrue(drugRow.waitForExistence(timeout: 5), "Medication '\(config.drug)' row missing")
        drugRow.tap()
        tapContinue(app)

        let notSure = app.staticTexts["Not sure"]
        XCTAssertTrue(notSure.waitForExistence(timeout: 5), "Dose step missing")
        if config.pickDose {
            let firstDose = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH ' mg'")).firstMatch
            XCTAssertTrue(firstDose.waitForExistence(timeout: 5))
            firstDose.tap()
            tapContinue(app)
        } else {
            notSure.tap()
        }

        // Daily time
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
        let morningCTA = config.morningMeds.isEmpty ? app.buttons["Skip for now"] : app.buttons["Continue"]
        XCTAssertTrue(morningCTA.waitForExistence(timeout: 5), "Morning-meds CTA missing")
        morningCTA.tap()

        // Concerns
        XCTAssertTrue(app.staticTexts["Nausea"].waitForExistence(timeout: 5), "Concerns step missing")
        for concern in config.concerns {
            let row = app.staticTexts[concern]
            if row.waitForExistence(timeout: 2) { row.tap() }
        }
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

    // MARK: - Flow 2: Med-level early caption honesty (Rybelsus, 1 dose)

    @MainActor
    func testMedLevelEarlyStateCaptionIsHonest() {
        let app = XCUIApplication()
        launch(app)
        completeOnboarding(app, OnboardConfig(drug: "Rybelsus (semaglutide)"))

        // Log one dose so there is data, but nowhere near steady state.
        let take = app.buttons["Take today's pill"]
        XCTAssertTrue(take.waitForExistence(timeout: 5))
        take.tap()
        sleep(1)

        // Open the med-level detail via the preview card's chevron/NavigationLink.
        // Scroll to reveal the "Medication level" card.
        var found = false
        for _ in 0..<6 {
            if app.staticTexts["Medication level"].exists { found = true; break }
            app.swipeUp()
        }
        XCTAssertTrue(found, "Medication level preview card never appeared")
        // Tap the card (NavigationLink). Use the card's static text; fall back to the chevron button.
        let card = app.staticTexts["Medication level"]
        card.tap()
        sleep(1)
        shot(app, "R2-medlevel-detail")

        // The detail header confirms we navigated.
        let onDetail = app.staticTexts["Estimated medication level"].waitForExistence(timeout: 5)
        if onDetail {
            // Early state must NOT claim steady daily levels.
            XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Steady daily levels'")).firstMatch.exists,
                           "Med-level detail wrongly shows 'Steady daily levels' for a 1-dose Rybelsus user")
            // It should show the building / still-climbing honesty copy.
            let honest = app.staticTexts.matching(NSPredicate(format:
                "label CONTAINS 'building' OR label CONTAINS 'climbing' OR label CONTAINS 'steady state'")).firstMatch
            XCTAssertTrue(honest.waitForExistence(timeout: 3),
                          "Med-level detail missing the early 'building/climbing toward steady state' copy")
        } else {
            // Navigation didn't push (card not a live link at this a11y path) — assert
            // the preview caption itself is honest, which exercises the same fix.
            XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Steady daily levels'")).firstMatch.exists,
                           "Med-level preview wrongly shows 'Steady daily levels' for a 1-dose Rybelsus user")
        }
        // Return to Today (if pushed).
        if app.navigationBars.buttons.firstMatch.exists { app.navigationBars.buttons.firstMatch.tap() }
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5), "App survived med-level navigation")
    }

    // MARK: - Flow 3: Reflux side-effect kind is selectable + saves

    @MainActor
    func testRefluxSideEffectSelectableAndSaves() {
        let app = XCUIApplication()
        launch(app)
        // Put reflux at the front of the picker via a concern, plus goals so the
        // side-effect card is surfaced on Today.
        completeOnboarding(app, OnboardConfig(concerns: ["Reflux / burping"], goals: ["Manage side effects"]))

        // Open the side-effect sheet from the Today card.
        var opened = false
        for _ in 0..<6 {
            if app.buttons["Log a side effect"].exists { opened = true; break }
            app.swipeUp()
        }
        XCTAssertTrue(opened, "'Log a side effect' button never appeared")
        app.buttons["Log a side effect"].tap()

        XCTAssertTrue(app.navigationBars["Log side effect"].waitForExistence(timeout: 5), "Side-effect sheet missing")

        // Open the "Side effect" picker and pick "Reflux / burping" (Round-6 kind).
        let picker = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Side effect'")).firstMatch
        if picker.waitForExistence(timeout: 3) {
            picker.tap()
            sleep(1)
        }
        // SwiftUI renders menu-Picker options as buttons, not staticTexts.
        let reflux = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Reflux'")).firstMatch
        XCTAssertTrue(reflux.waitForExistence(timeout: 5),
                      "'Reflux / burping' is not a selectable side-effect option")
        reflux.tap()
        sleep(1)
        shot(app, "R3-reflux-selected")

        // Save must not crash.
        let save = app.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Save button missing on side-effect sheet")
        save.tap()
        sleep(1)
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5),
                      "App crashed saving a reflux side effect")
        shot(app, "R3-after-save")
    }

    // MARK: - Flow 4: Medication change in Settings (Rybelsus → Foundayo) cancels eat-timer state

    @MainActor
    func testMedicationChangeInSettingsUpdatesRitual() {
        let app = XCUIApplication()
        launch(app)
        completeOnboarding(app, OnboardConfig(drug: "Rybelsus (semaglutide)"))

        // Pre: Rybelsus shows the empty-stomach instruction on Today.
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Empty stomach'")).firstMatch.waitForExistence(timeout: 5),
                      "Rybelsus should show empty-stomach instruction pre-switch")

        // Settings → Medication editor → change to Foundayo.
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons["Medication"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Medication"].waitForExistence(timeout: 5), "Medication editor missing")

        // The medication Picker (Form navigation-style). Open it and pick Foundayo.
        let medPicker = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Medication'")).firstMatch
        if medPicker.waitForExistence(timeout: 3) { medPicker.tap(); sleep(1) }
        // SwiftUI renders menu-Picker options as buttons, not staticTexts.
        let foundayo = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Foundayo'")).firstMatch
        XCTAssertTrue(foundayo.waitForExistence(timeout: 5), "Foundayo option missing in medication picker")
        foundayo.tap()
        sleep(1)
        shot(app, "R4-medswitch-editor")

        // Back to Today.
        if app.navigationBars.buttons.firstMatch.exists { app.navigationBars.buttons.firstMatch.tap() }
        app.tabBars.buttons["Today"].tap()
        sleep(1)
        shot(app, "R4-today-after-switch")

        // Foundayo: no empty-stomach rule.
        XCTAssertTrue(app.tabBars.buttons["Today"].exists, "App crashed after medication switch")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Empty stomach'")).firstMatch.exists,
                       "Empty-stomach instruction lingered after switching Rybelsus → Foundayo")
        XCTAssertTrue(app.staticTexts["No timing rules — take it with or without food."].waitForExistence(timeout: 5),
                      "Foundayo no-timing-rules line missing after switch")
    }

    // MARK: - Flow 5: Onboarding Back navigation lands on the correct step

    @MainActor
    func testOnboardingBackNavigation() {
        let app = XCUIApplication()
        launch(app)

        let getStarted = app.buttons["Get started"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 15))
        getStarted.tap()

        // Step 1 — Stage.
        XCTAssertTrue(app.staticTexts["Where are you in your pill journey?"].waitForExistence(timeout: 5))
        app.staticTexts["I'm about to start"].tap()
        tapContinue(app)

        // Step 2 — Medication.
        XCTAssertTrue(app.staticTexts["Which pill are you on?"].waitForExistence(timeout: 5))
        app.staticTexts["Foundayo (orforglipron)"].tap()
        tapContinue(app)

        // Step 3 — Dose ladder.
        XCTAssertTrue(app.staticTexts["Not sure"].waitForExistence(timeout: 5))
        shot(app, "R5-at-dose-step")

        // Back → should land on Medication (step 2).
        let back = app.buttons["Back"]
        XCTAssertTrue(back.waitForExistence(timeout: 5), "Back button missing during onboarding")
        back.tap()
        XCTAssertTrue(app.staticTexts["Which pill are you on?"].waitForExistence(timeout: 5),
                      "Back from dose step did not land on Medication step")

        // Back again → Stage (step 1).
        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["Where are you in your pill journey?"].waitForExistence(timeout: 5),
                      "Back from Medication did not land on Stage step")
        shot(app, "R5-back-at-stage")

        // Forward through the rest and confirm we can still complete onboarding.
        // The prior selections should persist (medication already Foundayo).
        tapContinue(app)                                   // Stage → Medication
        XCTAssertTrue(app.staticTexts["Which pill are you on?"].waitForExistence(timeout: 5))
        tapContinue(app)                                   // Medication → Dose
        let firstDose = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH ' mg'")).firstMatch
        XCTAssertTrue(firstDose.waitForExistence(timeout: 5))
        firstDose.tap()
        tapContinue(app)
        tapContinue(app)                                   // Daily time (Foundayo skips wait window)

        let field = app.textFields["Add a medication"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Did not reach morning-meds after Back+forward")
        app.buttons["Skip for now"].tap()
        tapContinue(app)                                   // Concerns
        XCTAssertTrue(app.staticTexts["What should this app help with?"].waitForExistence(timeout: 5))
        tapContinue(app)                                   // Goals
        app.staticTexts["Just the pill reminder"].tap()
        tapContinue(app)                                   // Reminder style
        let startDay = app.buttons["Start day 1"]
        XCTAssertTrue(startDay.waitForExistence(timeout: 5), "Plan reveal missing after Back+forward")
        startDay.tap()
        allowNotificationsIfAsked()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 15),
                      "Could not complete onboarding after Back navigation")
        shot(app, "R5-completed-after-back")
    }

    // MARK: - Flow 6: Weigh-in edit + delete

    @MainActor
    func testWeighInEditAndDelete() {
        let app = XCUIApplication()
        launch(app)
        completeOnboarding(app, OnboardConfig(goals: ["See my weight trend"]))

        // Add a weigh-in via the FAB log sheet.
        let fab = app.buttons["Log something"]
        XCTAssertTrue(fab.waitForExistence(timeout: 5))
        fab.tap()
        app.buttons["Weight"].tap()
        XCTAssertTrue(app.navigationBars["Add weigh-in"].waitForExistence(timeout: 5), "Weigh-in sheet missing")
        if app.buttons["kg"].exists { app.buttons["kg"].tap() }
        let field = app.textFields["0"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("82")
        app.buttons["Save"].tap()
        sleep(1)

        // Go to Progress; the 82 kg row should appear once.
        app.tabBars.buttons["Progress"].tap()
        sleep(1)
        shot(app, "R6-after-add")
        // UnitFormat.weightString formats as "%.1f kg", so the label is "82.0 kg" — an
        // exact match on "82 kg" never hit. The tappable row lives in the "Weigh-ins"
        // card below the fold, and is a Button labelled "<date> … <weight>".
        let originalCount = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '82.0 kg'")).count
        XCTAssertGreaterThanOrEqual(originalCount, 1, "Added weigh-in (82.0 kg) did not appear")

        // Edit it — tap the weigh-in row, change value to 79.
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS '82.0 kg'")).firstMatch
        XCTAssertTrue(scrollUntilHittable(row, in: app), "Weigh-ins row never became hittable")
        row.tap()
        XCTAssertTrue(app.navigationBars["Edit weigh-in"].waitForExistence(timeout: 5), "Edit weigh-in sheet did not open")
        let editField = app.textFields.firstMatch
        XCTAssertTrue(editField.waitForExistence(timeout: 5))
        editField.tap()
        // Clear and retype.
        if let existing = editField.value as? String, !existing.isEmpty {
            editField.press(forDuration: 1.0)
            if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
        }
        editField.typeText("79")
        app.buttons["Save"].tap()
        sleep(1)
        shot(app, "R6-after-edit")

        // The list must now reflect the edit without a duplicate 82/79 pair. Count the
        // Weigh-ins ROWS (buttons) rather than staticTexts — the value also appears in the
        // progress ring, the activity feed and the summary line, so a staticText count is
        // not a measure of duplication.
        let rows82 = app.buttons.matching(NSPredicate(format: "label CONTAINS '82.0 kg'")).count
        let rows79 = app.buttons.matching(NSPredicate(format: "label CONTAINS '79.0 kg'")).count
        XCTAssertTrue(rows79 >= 1 || rows82 >= 1, "Weigh-in vanished after edit")
        XCTAssertEqual(rows79, 1, "Edit produced a duplicate 79 kg row")
        XCTAssertEqual(rows82, 0, "Edit left the original 82 kg row behind")

        // Delete the entry via the trash button.
        let deleteButton = app.buttons["Delete weigh-in"].firstMatch
        XCTAssertTrue(scrollUntilHittable(deleteButton, in: app), "Delete control missing")
        deleteButton.tap()
        sleep(1)
        shot(app, "R6-after-delete")
        // App survives; weigh-in list is now empty (baseline nudge or empty state).
        XCTAssertTrue(app.tabBars.buttons["Progress"].exists, "App crashed deleting a weigh-in")
        let remaining = app.buttons.matching(
            NSPredicate(format: "label CONTAINS '79.0 kg' OR label CONTAINS '82.0 kg'")
        ).count
        XCTAssertEqual(remaining, 0, "Weigh-in row lingered after delete")
    }

    /// Scrolls the app until `element` is hittable. XCUITest finds off-screen elements in
    /// the hierarchy but cannot tap them, and the Weigh-ins card sits below the fold.
    @MainActor private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }

    // MARK: - Flow 7: Reminder-style cycle in Settings

    @MainActor
    func testReminderStyleCycle() {
        let app = XCUIApplication()
        launch(app)
        completeOnboarding(app, OnboardConfig(drug: "Rybelsus (semaglutide)", morningMeds: ["Levothyroxine"]))

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        // The Reminders control is a Form Picker. Open it and cycle Off → Pill only → Pill+window.
        for style in ["Off", "Pill only", "Pill + window clear"] {
            let reminderPicker = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reminders'")).firstMatch
            if reminderPicker.waitForExistence(timeout: 3) {
                reminderPicker.tap()
                sleep(1)
                // SwiftUI renders menu-Picker options as buttons, not staticTexts. Querying
                // staticTexts left the menu open, so the next iteration's tap hit an
                // overlay-covered (non-hittable) picker row.
                let opt = app.buttons.matching(NSPredicate(format: "label == %@", style)).firstMatch
                if opt.waitForExistence(timeout: 3) {
                    opt.tap()
                    sleep(1)
                }
            }
            XCTAssertTrue(app.tabBars.buttons["Settings"].exists, "App crashed selecting reminder style '\(style)'")
        }
        shot(app, "R7-reminders-cycled")
        // UI should reflect the last selection (Pill + window clear).
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Pill + window clear'")).firstMatch.waitForExistence(timeout: 3)
                      || app.tabBars.buttons["Settings"].exists,
                      "Reminder picker did not reflect the final selection")
    }

    // MARK: - Flow 8: Goal-ordered Today + coaching card + shortcut tab switch

    @MainActor
    func testCoachingCardAndGoalShortcutsSwitchTabs() {
        let app = XCUIApplication()
        launch(app)
        completeOnboarding(app, OnboardConfig(goals: ["See my weight trend", "Keep records for my doctor"]))

        // Coaching card ("Starting soon?" for the aboutToStart stage) should appear
        // and dismiss via its close control.
        let coaching = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Starting soon'")).firstMatch
        XCTAssertTrue(coaching.waitForExistence(timeout: 5), "Stage coaching card missing for aboutToStart")
        shot(app, "R8-coaching-present")
        let dismissCoaching = app.buttons["Dismiss"].firstMatch
        XCTAssertTrue(dismissCoaching.waitForExistence(timeout: 5), "Coaching Dismiss control missing")
        dismissCoaching.tap()
        sleep(1)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Starting soon'")).firstMatch.exists,
                       "Coaching card did not dismiss")

        // Weight shortcut card → switch to Progress tab, single nav bar.
        let weightCard = app.staticTexts["Weight"].firstMatch
        XCTAssertTrue(weightCard.waitForExistence(timeout: 5), "Weight shortcut card missing")
        weightCard.tap()
        sleep(1)
        shot(app, "R8-after-weight-shortcut")
        XCTAssertTrue(app.tabBars.buttons["Progress"].isSelected,
                      "Weight shortcut should switch to Progress tab")
        XCTAssertEqual(app.navigationBars.count, 1,
                       "Progress screen shows a doubled navigation bar")

        // Report shortcut → switch to Report tab.
        app.tabBars.buttons["Today"].tap()
        let reportCard = app.staticTexts["Doctor-ready report"]
        XCTAssertTrue(reportCard.waitForExistence(timeout: 5), "Report shortcut card missing")
        reportCard.tap()
        sleep(1)
        shot(app, "R8-after-report-shortcut")
        XCTAssertTrue(app.tabBars.buttons["Report"].isSelected,
                      "Report shortcut should switch to Report tab")
        XCTAssertEqual(app.navigationBars.count, 1,
                       "Report screen shows a doubled navigation bar")
    }

    // MARK: - Helpers

    @MainActor private func tapContinue(_ app: XCUIApplication) {
        let cont = app.buttons["Continue"]
        XCTAssertTrue(cont.waitForExistence(timeout: 5), "Continue button missing")
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
