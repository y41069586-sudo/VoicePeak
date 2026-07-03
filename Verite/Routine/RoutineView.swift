import SwiftUI

/// Placeholder for the proven routine + timer. Built from products that passed
/// their half-face test. Real implementation arrives in Milestone 7.
struct RoutineView: View {
    var body: some View {
        ComingSoonView(titleKey: AppTab.routine.titleKey,
                       systemImage: AppTab.routine.systemImage,
                       messageKey: "routine.comingSoon")
    }
}
