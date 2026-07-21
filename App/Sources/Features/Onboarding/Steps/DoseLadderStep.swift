import SwiftUI

struct DoseLadderStep: View {
    @Bindable var store: OnboardingStore
    let next: () -> Void
    @State private var customMg: Double? = nil

    private var ladder: [Double] { MedicationLadder.doses(for: store.kind) }
    private var selectedMg: Double? { store.steps.first?.doseMg }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's your current dose?").font(.title.bold()).padding(.top, 24)
            Text("Most people begin at the lowest dose and step up about every 30 days. Not sure is fine.")
                .font(.subheadline).foregroundStyle(.secondary)
            if ladder.isEmpty {
                LabeledContent("Dose (mg)") {
                    TextField("0", value: $customMg, format: .number)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
                        .onChange(of: customMg) { _, v in if let v { store.steps = [.init(doseMg: v, durationWeeks: 4)] } }
                }
                .padding().background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(ladder, id: \.self) { dose in
                            OnboardingOptionRow(title: "\(dose.formatted()) mg", subtitle: nil, selected: selectedMg == dose, multi: false) {
                                store.steps = [.init(doseMg: dose, durationWeeks: 4)]
                            }
                        }
                        OnboardingOptionRow(title: "Not sure", subtitle: "You can change this anytime", selected: false, multi: false) {
                            store.steps = [.init(doseMg: ladder.first ?? 0.8, durationWeeks: 4)]; next()
                        }
                    }
                }
            }
            Spacer()
            PillCTAButton(title: "Continue", systemImage: "arrow.right") { next() }.padding(.bottom, 24)
        }
        .padding(.horizontal).background(Color(.systemGroupedBackground))
    }
}
