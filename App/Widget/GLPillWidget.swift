import WidgetKit
import SwiftUI

// Brand colours, mirrored from the app's Theme (the widget target doesn't compile Theme.swift).
private enum WidgetTheme {
    static let primary = Color(red: 0.055, green: 0.486, blue: 0.482)
    static let mint = Color(red: 0.42, green: 0.78, blue: 0.67)
    static let gradient = LinearGradient(
        colors: [primary, mint],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct GLPillEntry: TimelineEntry {
    let date: Date
    let snapshot: GLPillWidgetSnapshot
}

struct GLPillProvider: TimelineProvider {
    func placeholder(in context: Context) -> GLPillEntry {
        GLPillEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (GLPillEntry) -> Void) {
        let snapshot = context.isPreview ? .placeholder : GLPillWidgetBridge.load()
        completion(GLPillEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GLPillEntry>) -> Void) {
        let snapshot = GLPillWidgetBridge.load()
        let now = Date()
        let calendar = Calendar.current
        let nextMidnight = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(60 * 60 * 6)

        // Two entries so the widget updates itself at midnight without waiting on
        // the app: after midnight, today's dose is no longer "taken" until the app
        // writes a fresh snapshot — otherwise the widget shows a stale "Taken today"
        // overnight.
        var afterMidnight = snapshot
        afterMidnight.doseTakenToday = false

        let entries = [
            GLPillEntry(date: now, snapshot: snapshot),
            GLPillEntry(date: nextMidnight, snapshot: afterMidnight)
        ]
        completion(Timeline(entries: entries, policy: .after(nextMidnight)))
    }
}

struct GLPillWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GLPillEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        default:
            small
        }
    }

    // MARK: - Home Screen small

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                Text("\(entry.snapshot.streak)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            Text("\(entry.snapshot.streak)-day streak")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))

            Spacer(minLength: 8)

            statusPill
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { WidgetTheme.gradient }
    }

    private var statusPill: some View {
        HStack(spacing: 5) {
            Image(systemName: entry.snapshot.doseTakenToday ? "checkmark.circle.fill" : "pills.fill")
                .font(.system(size: 13, weight: .bold))
            Text(entry.snapshot.doseTakenToday ? "Taken today" : "Take today's pill")
                .font(.system(size: 12, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(entry.snapshot.doseTakenToday ? WidgetTheme.primary : .white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(entry.snapshot.doseTakenToday ? Color.white : Color.white.opacity(0.22))
        )
    }

    // MARK: - Lock Screen circular

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12))
                Text("\(entry.snapshot.streak)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
        }
        .widgetAccentable()
    }

    // MARK: - Lock Screen rectangular

    private var rectangular: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 22))
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 1) {
                Text("\(entry.snapshot.streak)-day streak")
                    .font(.headline)
                Text(entry.snapshot.doseTakenToday ? "Taken today ✓" : "Take today's pill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GLPillWidget: Widget {
    let kind = "GLPillWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GLPillProvider()) { entry in
            GLPillWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Pill Streak")
        .description("Your daily GLP-1 streak and today's status at a glance.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct GLPillWidgetBundle: WidgetBundle {
    var body: some Widget {
        GLPillWidget()
    }
}
