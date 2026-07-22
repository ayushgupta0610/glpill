import SwiftUI

struct PlanRevealStep: View {
    @Bindable var store: OnboardingStore
    let finish: () -> Void
    private var pillName: String { store.kind == .custom ? (store.customName.isEmpty ? "your pill" : store.customName) : store.kind.defaultDisplayName }
    private var timeText: String {
        let c = DateComponents(hour: store.reminderHour, minute: store.reminderMinute)
        let d = Calendar.current.date(from: c) ?? .now
        return d.formatted(date: .omitted, time: .shortened)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Spacer(minLength: 24)
                VStack(alignment: .leading, spacing: 12) {
                Text("YOUR DAILY PLAN").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.85))
                Text("You're set 🌱").font(.largeTitle.bold()).foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 6) {
                    Label("\(timeText) — take \(pillName)", systemImage: "pills.fill")
                    if store.requiresEmptyStomach {
                        Label("Wait \(store.waitWindowMinutes) min — we'll time it", systemImage: "clock.fill")
                    }
                    if let firstMed = store.morningMeds.first {
                        Label("Then — \(firstMed) + breakfast", systemImage: "fork.knife")
                    }
                    Label("Reminders on · streak starts today", systemImage: "flame.fill")
                }
                .font(.subheadline).foregroundStyle(.white)
                .padding().frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
            }
            .padding().frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 24))
                Text("Free to use. No card needed.").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            PillCTAButton(title: "Start day 1", systemImage: "checkmark") { finish() }
                .padding(.horizontal).padding(.bottom, 24)
        }
    }
}
