import SwiftUI

/// Placeholder for the live camera + AR alignment scan. Real capture pipeline
/// arrives in Milestone 2.
struct ScanView: View {
    var body: some View {
        ComingSoonView(titleKey: AppTab.scan.titleKey,
                       systemImage: AppTab.scan.systemImage,
                       messageKey: "scan.comingSoon")
    }
}
