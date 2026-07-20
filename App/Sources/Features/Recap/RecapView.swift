import SwiftUI
import SwiftData

/// "My Month" — the Consistency Wrapped screen. Previews the shareable card and
/// lets the user optionally add a non-scale victory or their weight change
/// (both off by default) before sharing.
struct RecapView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [UserSettings]
    @Query private var weights: [WeightEntry]

    @State private var includeWeight = false
    @State private var nonScaleVictory: String?
    @State private var name = ""

    /// Caps the name so it can't overflow the fixed-size rasterized share card.
    private static let maxNameLength = 20

    private let victories = ["More energy", "Clothes fit better", "Food noise quiet", "Slept better", "Feeling stronger"]

    private var metric: Bool { settingsList.first?.usesMetric ?? false }

    private var hasWeightThisMonth: Bool {
        let interval = Calendar.current.dateInterval(of: .month, for: .now)
        return weights.filter { interval?.contains($0.date) ?? false }.count >= 2
    }

    private var recap: MonthlyRecap {
        RecapBuilder.build(
            context: context,
            startDate: settingsList.first?.startDate ?? .now,
            includeWeight: includeWeight,
            nonScaleVictory: nonScaleVictory,
            firstName: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : name
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    WrappedCardView(recap: recap, metric: metric)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
                        .padding(.top, 8)

                    nameField

                    victoryPicker

                    if hasWeightThisMonth {
                        Toggle(isOn: $includeWeight) {
                            Text("Include my weight change")
                                .font(.subheadline.weight(.medium))
                        }
                        .tint(Theme.primary)
                        .padding(.horizontal, 4)
                    }

                    if let image = shareImage() {
                        ShareLink(
                            item: Image(uiImage: image),
                            preview: SharePreview("My month on GLPill", image: Image(uiImage: image))
                        ) {
                            Label("Share my month", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Theme.primary, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }

                    Text("Nothing here names your medication. Weight is added only if you turn it on.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("My Month")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { name = settingsList.first?.firstName ?? "" }
            .onChange(of: name) { _, newValue in
                if newValue.count > Self.maxNameLength {
                    name = String(newValue.prefix(Self.maxNameLength))
                    return
                }
                persist(name: newValue)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var nameField: some View {
        HStack {
            Text("Your name").font(.subheadline.weight(.medium))
            Spacer()
            TextField("Optional", text: $name)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func persist(name newValue: String) {
        guard let settings = settingsList.first else { return }
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.firstName = trimmed.isEmpty ? nil : trimmed
        try? context.save()
    }

    private var victoryPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add a non-scale win? (optional)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(victories, id: \.self) { victory in
                        let selected = nonScaleVictory == victory
                        Button {
                            nonScaleVictory = selected ? nil : victory
                        } label: {
                            Text(victory)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(selected ? Theme.primary : Color(.secondarySystemBackground), in: Capsule())
                                .foregroundStyle(selected ? .white : .primary)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    @MainActor
    private func shareImage() -> UIImage? {
        let renderer = ImageRenderer(content: WrappedCardView(recap: recap, metric: metric))
        renderer.scale = 3
        return renderer.uiImage
    }
}
