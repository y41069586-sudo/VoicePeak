import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Lightweight haptic vocabulary. UIKit feedback generators cover every M1 need;
/// a CoreHaptics engine can be added later for the verified-reveal flourish.
enum Haptics {

    enum Event {
        case capture        // shutter tick
        case verdictReveal  // the honest verdict lands
        case riskFlagged    // a product is flagged as risky (heavier, warning)
        case milestone      // test milestone / streak
        case selection      // light UI selection
        case transition     // soft tick on onboarding/flow screen transitions
        case tick           // light tick during score count-ups
    }

    @MainActor
    static func fire(_ event: Event) {
        #if canImport(UIKit)
        switch event {
        case .capture:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .verdictReveal:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .riskFlagged:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .milestone:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .transition:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .tick:
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
        }
        #endif
    }
}
