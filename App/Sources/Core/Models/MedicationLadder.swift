import Foundation

/// Verified FDA titration ladders per pill (mg). Presented in onboarding as
/// tappable dose options; the app never recommends escalating — it only lets a
/// user record the dose their prescriber gave them.
enum MedicationLadder {
    static func doses(for kind: MedicationKind) -> [Double] {
        switch kind {
        case .rybelsus: return [3, 7, 14]
        case .foundayo: return [0.8, 2.5, 5.5, 9, 14.5, 17.2]
        case .wegovyPill: return [1.5, 4, 9, 25]
        case .custom: return []
        }
    }
}
