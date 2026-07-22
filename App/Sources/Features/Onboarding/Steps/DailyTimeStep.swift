import SwiftUI

struct DailyTimeStep: View {
    @Bindable var store: OnboardingStore
    let next: () -> Void
    @State private var time = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? .now

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("When will you take it each day?").font(.title.bold()).padding(.top, 24)
                Text(store.requiresEmptyStomach
                     ? "Oral semaglutide works best first thing, on an empty stomach."
                     : "Pick a time you'll remember — Foundayo works any time of day.")
                    .font(.subheadline).foregroundStyle(.secondary)
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel).labelsHidden().frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            PillCTAButton(title: "Continue", systemImage: "arrow.right") {
                let c = Calendar.current.dateComponents([.hour, .minute], from: time)
                store.reminderHour = c.hour ?? 7
                store.reminderMinute = c.minute ?? 0
                next()
            }
            .padding(.horizontal).padding(.bottom, 24)
        }
    }
}
