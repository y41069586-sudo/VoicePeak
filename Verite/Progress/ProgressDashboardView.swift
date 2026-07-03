import SwiftUI

/// Placeholder for the whole-face timeline + per-attribute trends (Swift Charts).
/// Real implementation arrives in Milestone 7.
struct ProgressDashboardView: View {
    var body: some View {
        ComingSoonView(titleKey: AppTab.progress.titleKey,
                       systemImage: AppTab.progress.systemImage,
                       messageKey: "progress.comingSoon")
    }
}
