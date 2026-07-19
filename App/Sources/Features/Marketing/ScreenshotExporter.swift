#if DEBUG
import SwiftUI
import UIKit
import Charts

/// DEBUG-only: renders the five App Store screenshots (6.9" = 1290×2796) to PNGs in
/// the app's Documents directory. Triggered by the `-exportScreenshots` launch argument.
/// Each screen reuses the real app components (Card / StatBadge / Theme) with attractive
/// sample data so the shots match the shipping UI. Pull them with:
///   xcrun simctl get_app_container booted com.ayushgupta.glpill data
@MainActor
enum ScreenshotExporter {
    static func export() {
        let shots: [(String, AnyView)] = [
            ("shot-1-today", AnyView(TodayShot())),
            ("shot-2-timer", AnyView(TimerShot())),
            ("shot-3-progress", AnyView(ProgressShot())),
            ("shot-4-report", AnyView(ReportShot())),
            ("shot-5-private", AnyView(PrivateShot())),
        ]
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for (name, view) in shots {
            let renderer = ImageRenderer(content: view.frame(width: 430, height: 932))
            renderer.scale = 3
            guard let image = renderer.uiImage, let data = image.pngData() else { continue }
            try? data.write(to: dir.appendingPathComponent("\(name).png"))
        }
    }
}

// MARK: - Shared frame

private struct ScreenshotFrame<Content: View>: View {
    let headline: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)
            VStack(spacing: 10) {
                Text(headline)
                    .font(.system(size: 33, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryDeep)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 26)

            VStack(spacing: 16) {
                content
            }
            .padding(.horizontal, 26)

            // Two bottom spacers vs one top → content sits ~1/3 from the top.
            Spacer(minLength: 40)
            Spacer(minLength: 40)
        }
        .frame(width: 430, height: 932)
        .background(
            LinearGradient(
                colors: [Theme.mint.opacity(0.18), Color(red: 0.97, green: 0.98, blue: 0.97)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }
}

// MARK: - Shot 1: Today + streak

private struct TodayShot: View {
    var body: some View {
        ScreenshotFrame(
            headline: "One tap a day",
            subtitle: "Log your pill, keep your streak alive."
        ) {
            Card {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rybelsus").font(.headline)
                        Text("7 mg — step 2 of 3 · next step Aug 4")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Label("Taken at 8:04 AM", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }
            Card {
                HStack(spacing: 16) {
                    Image(systemName: "flame.fill").font(.title).foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("42-day streak").font(.title3.bold())
                        Text("Longest: 42 days").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            Card {
                HStack {
                    StatBadge(value: "128 g", label: "Protein today")
                    StatBadge(value: "1.6 L", label: "Water", tint: .blue)
                }
            }
        }
    }
}

// MARK: - Shot 2: Rybelsus timer

private struct TimerShot: View {
    var body: some View {
        ScreenshotFrame(
            headline: "We time the 30-minute wait",
            subtitle: "Rybelsus works on an empty stomach — we tell you the exact minute you can eat."
        ) {
            Card {
                HStack(spacing: 16) {
                    Image(systemName: "clock.fill").font(.title).foregroundStyle(Theme.warn)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("24:31").font(.title2.bold()).monospacedDigit()
                        Text("You can eat at 8:34 AM")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            Card {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rybelsus").font(.headline)
                        Text("Taken on an empty stomach")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "pills.fill").font(.title2).foregroundStyle(Theme.primary)
                }
            }
            Card {
                SectionHeader(title: "Why it matters")
                Text("Eating too soon can cut how much medicine your body absorbs. GLPill starts the countdown automatically the moment you log your pill.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Shot 3: Progress chart

private struct ProgressShot: View {
    private struct Point: Identifiable { let id = UUID(); let week: Int; let lb: Double }
    private let points: [Point] = [
        .init(week: 0, lb: 214), .init(week: 1, lb: 211), .init(week: 2, lb: 208),
        .init(week: 3, lb: 206), .init(week: 4, lb: 202), .init(week: 5, lb: 199),
        .init(week: 6, lb: 196), .init(week: 7, lb: 193), .init(week: 8, lb: 191),
        .init(week: 10, lb: 187), .init(week: 12, lb: 182),
    ]

    var body: some View {
        ScreenshotFrame(
            headline: "Watch it work",
            subtitle: "Your weight trend, milestones, and share-ready cards."
        ) {
            Card {
                HStack {
                    StatBadge(value: "182 lb", label: "Current")
                    StatBadge(value: "−32 lb", label: "Total change", tint: .orange)
                    StatBadge(value: "12 lb", label: "To goal", tint: .blue)
                }
            }
            Card {
                SectionHeader(title: "Weight trend")
                Chart(points) { p in
                    LineMark(x: .value("Week", p.week), y: .value("Weight", p.lb))
                        .foregroundStyle(Theme.primary)
                        .interpolationMethod(.catmullRom)
                    AreaMark(x: .value("Week", p.week), y: .value("Weight", p.lb))
                        .foregroundStyle(Theme.primary.opacity(0.12))
                        .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: 175...220)
                .frame(height: 240)
                .clipped()
            }
        }
    }
}

// MARK: - Shot 4: Doctor report

private struct ReportShot: View {
    private let report = """
    GLP-1 pill — 4-week summary
    Adherence: 96% (27 of 28 days)
    Current dose: 7 mg daily
    Weight change: −8.4 lb
    Side effects: nausea (mild) ×2

    Generated by GLPill
    """

    var body: some View {
        ScreenshotFrame(
            headline: "Walk into appointments prepared",
            subtitle: "A doctor-ready summary: adherence, doses, weight, side effects."
        ) {
            Card {
                HStack {
                    StatBadge(value: "96%", label: "Adherence")
                    StatBadge(value: "−8.4 lb", label: "Weight change", tint: .orange)
                    StatBadge(value: "2", label: "Side effects", tint: Theme.warn)
                }
            }
            HStack(spacing: 8) {
                Text("Share with your doctor")
                Image(systemName: "square.and.arrow.up")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.primary, in: RoundedRectangle(cornerRadius: 12))
            Card {
                SectionHeader(title: "Full report")
                Text(report)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
    }
}

// MARK: - Shot 5: Private by design

private struct PrivateShot: View {
    var body: some View {
        ScreenshotFrame(
            headline: "Private by design",
            subtitle: "No account. No servers. Your data stays on your iPhone."
        ) {
            Card {
                feature("iphone.and.arrow.forward", "Stays on your device", "Nothing is uploaded to us — ever.")
                Divider()
                feature("icloud.fill", "Your own private iCloud", "Syncs across your devices; we can't read it.")
                Divider()
                feature("hand.raised.fill", "No tracking, no ads", "Zero analytics, zero advertising identifiers.")
                Divider()
                feature("lock.shield.fill", "No sign-up needed", "Open the app and start — no email, no name.")
            }
            Card {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2).foregroundStyle(Theme.primary)
                    Text("App Store privacy label: **Data Not Collected**")
                        .font(.subheadline)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func feature(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.primary)
                .frame(width: 34, height: 34)
                .background(Theme.primary.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}
#endif
