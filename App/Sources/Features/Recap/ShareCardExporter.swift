#if DEBUG
import SwiftUI
import UIKit

/// DEBUG-only utility: renders the shareable cards to PNGs in the app's Documents
/// directory. Used for visual QA and for generating marketing share-card images
/// without navigating the app UI. Triggered by the `-exportCards` launch argument.
@MainActor
enum ShareCardExporter {
    static func exportSamples() {
        let recap = MonthlyRecap(
            monthName: "July",
            firstName: "Ayush",
            currentStreak: 30,
            bestStreakThisMonth: 30,
            daysLogged: 30,
            daysElapsed: 30,
            consistencyPercent: 100,
            archetype: .quietMachine,
            nonScaleVictory: "Food noise quiet",
            weightChangeKg: nil
        )
        write(WrappedCardView(recap: recap), name: "wrapped-card.png")
        write(TrophyCardView(milestone: 30, name: "Ayush"), name: "trophy-card.png")
    }

    private static func write<V: View>(_ view: V, name: String) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        guard let image = renderer.uiImage, let data = image.pngData() else { return }
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
        try? data.write(to: url)
    }
}
#endif
