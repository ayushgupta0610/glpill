import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(SubscriptionStore.self) private var subscriptions
    @Query private var settingsList: [UserSettings]
    @State private var reminderTime = Date.now
    @State private var restoreMessage: String?
    @State private var showManageSubscription = false

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
                }

                if let settings = settingsList.first {
                    @Bindable var settings = settings
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

                    Section("Daily reminder") {
                        DatePicker("Remind me at", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .onChange(of: reminderTime) {
                                let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
                                settings.reminderHour = components.hour ?? 9
                                settings.reminderMinute = components.minute ?? 0
                                Task {
                                    let scheduler = UNNotificationScheduler()
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

                Everything you enter in GLPill — medication choice, dose plan and history, weight, side effects, protein and water — is stored only in a local database on your iPhone. GLPill has no servers, no accounts, no analytics, no ads, and no tracking. We never see, collect, transmit, share, or sell your data.

                Subscriptions are billed and managed entirely by Apple; we receive only an anonymous confirmation that a subscription is active — never your name, email, or payment details.

                Reminders are scheduled locally on your device. Reports and progress cards leave your phone only when you explicitly share them.

                Your data is protected with iOS's strongest file-protection class (encrypted whenever your device is locked). Deleting the app permanently deletes your data — there is nothing on any server to remove.

                Contact: ayushgupta0610@gmail.com
                """)
                .font(.subheadline)

                Link("Read the full policy at glpill-privacy.vercel.app",
                     destination: URL(string: "https://glpill-privacy.vercel.app/privacy.html")!)
                    .font(.subheadline.weight(.semibold))
            }
            .padding()
        }
        .navigationTitle("Privacy policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
