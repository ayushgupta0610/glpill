import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(SubscriptionStore.self) private var subscriptions
    @Query(sort: \UserSettings.createdAt) private var settingsList: [UserSettings]
    @State private var reminderTime = Date.now
    @State private var restoreMessage: String?
    @State private var showManageSubscription = false
    @State private var notificationsDenied = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    NavigationLink("Medication") {
                        MedicationEditor()
                    }
                    NavigationLink("Dose plan") {
                        TitrationEditor()
                    }
                    NavigationLink("Morning meds") {
                        MorningMedsEditor()
                    }
                }

                if let settings = settingsList.first {
                    @Bindable var settings = settings
                    Section {
                        TextField("First name (optional)", text: Binding(
                            get: { settings.firstName ?? "" },
                            set: { settings.firstName = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                        ))
                        .textInputAutocapitalization(.words)
                    } header: {
                        Text("Personal")
                    } footer: {
                        Text("Only used to personalize your shareable recap card. Stored on your device — never sent anywhere.")
                    }

                    Section("Units & targets") {
                        Picker("Weight unit", selection: $settings.usesMetric) {
                            Text("kg").tag(true)
                            Text("lb").tag(false)
                        }
                        Stepper("Protein target: \(settings.proteinTargetGrams) g",
                                value: $settings.proteinTargetGrams, in: 30...300, step: 5)
                        Stepper(
                            settings.usesMetric
                                ? "Water target: \(settings.waterTargetMl) ml"
                                : "Water target: \(Int((Double(settings.waterTargetMl) / 29.5735).rounded())) oz",
                            value: $settings.waterTargetMl, in: 500...5000, step: 250
                        )
                    }

                    Section {
                        Picker("Reminders", selection: $settings.reminderStyle) {
                            Text("Pill + window clear").tag("full")
                            Text("Pill only").tag("pillOnly")
                            Text("Off").tag("none")
                        }
                        .onChange(of: settings.reminderStyle) {
                            let style = settings.reminderStyle
                            Task {
                                let scheduler = UNNotificationScheduler()
                                // Leaving "full" means no eat-again nudge — cancel any
                                // in-flight "you can eat now" push mid-window.
                                if style != "full" {
                                    scheduler.removePending(ids: [ReminderScheduler.eatTimerId])
                                }
                                if style == "none" {
                                    scheduler.removePending(ids: [ReminderScheduler.dailyId])
                                } else if await scheduler.requestAuthorization() {
                                    ReminderScheduler.scheduleDaily(
                                        hour: settings.reminderHour,
                                        minute: settings.reminderMinute,
                                        using: scheduler
                                    )
                                }
                            }
                        }
                    } header: {
                        Text("Reminder style")
                    } footer: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("“Pill only” drops the eat-again nudge after your empty-stomach window. “Off” turns off the daily pill reminder.")
                            if notificationsDenied && settings.reminderStyle != "none" {
                                Text("Notifications are turned off for GLPill, so reminders can't be delivered. Turn them on in iOS Settings.")
                                    .foregroundStyle(Theme.warn)
                            }
                        }
                    }

                    Section("Daily reminder") {
                        DatePicker("Remind me at", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .onChange(of: reminderTime) {
                                let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
                                settings.reminderHour = components.hour ?? 9
                                settings.reminderMinute = components.minute ?? 0
                                Task {
                                    let scheduler = UNNotificationScheduler()
                                    // Don't resurrect a disabled ("Off") daily reminder just
                                    // because the user nudged the time picker.
                                    guard settings.reminderStyle != "none" else {
                                        scheduler.removePending(ids: [ReminderScheduler.dailyId])
                                        return
                                    }
                                    if await scheduler.requestAuthorization() {
                                        ReminderScheduler.scheduleDaily(
                                            hour: settings.reminderHour,
                                            minute: settings.reminderMinute,
                                            using: scheduler
                                        )
                                    }
                                }
                            }
                    }
                }

                Section("Subscription") {
                    LabeledContent("Status", value: subscriptions.isUnlocked ? "Active" : "Inactive")
                    Button("Manage subscription") {
                        showManageSubscription = true
                    }
                    Button("Restore purchases") {
                        Task {
                            await subscriptions.restore()
                            restoreMessage = subscriptions.isUnlocked
                                ? "Subscription restored."
                                : "No active subscription found for this Apple Account."
                        }
                    }
                }

                Section("About") {
                    NavigationLink("Privacy policy") {
                        PrivacyPolicyView()
                    }
                    Text("GLPill is a tracking tool, not medical advice. Never change your dose without talking to your prescriber.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Foundayo® is a trademark of Eli Lilly and Company. Rybelsus® is a trademark of Novo Nordisk A/S. GLPill is not affiliated with or endorsed by either company.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    LabeledContent("Version", value: "1.0.0")
                }
            }
            .navigationTitle("Settings")
            .manageSubscriptionsSheet(isPresented: $showManageSubscription)
            .task {
                notificationsDenied = await UNNotificationScheduler().authorizationStatus() == .denied
            }
            .onAppear {
                if let settings = settingsList.first {
                    reminderTime = Calendar.current.date(
                        from: DateComponents(hour: settings.reminderHour, minute: settings.reminderMinute)
                    ) ?? .now
                }
            }
            .alert("Restore", isPresented: .init(
                get: { restoreMessage != nil },
                set: { if !$0 { restoreMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(restoreMessage ?? "")
            }
        }
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("""
                GLPill Privacy Policy (summary)

                Everything you enter in GLPill — medication choice, dose plan and history, weight, side effects, protein and water — is stored on your device and synced privately through your own iCloud (Apple's, tied to your Apple ID). That means your history follows you to a new iPhone and survives a reinstall. GLPill has no servers of its own, no accounts, no analytics, no ads, and no tracking. We never see, collect, transmit, share, or sell your data — it stays within Apple's ecosystem, under your control.

                Subscriptions are billed and managed entirely by Apple; we receive only an anonymous confirmation that a subscription is active — never your name, email, or payment details. On a new phone, tap Restore Purchases to get your subscription back.

                Reminders are scheduled locally on your device. Reports and progress cards leave your phone only when you explicitly share them.

                On-device data is protected with iOS's strongest file-protection class (encrypted whenever your device is locked). To remove everything, delete the app and clear its iCloud data in Settings › your Apple Account › iCloud.

                Contact: support@glpillapp.com
                """)
                .font(.subheadline)

                Link("Read the full policy at glpillapp.com",
                     destination: URL(string: "https://glpillapp.com/privacy.html")!)
                    .font(.subheadline.weight(.semibold))
            }
            .padding()
        }
        .navigationTitle("Privacy policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
