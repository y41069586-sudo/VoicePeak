import SwiftUI
import SwiftData

// ============================================================
// MARK: — v2 shell: Scan / Routine / Progress
// ============================================================

struct DermiqTabShell: View {
    enum Tab: String, CaseIterable {
        case scan, routine, progress

        var title: String {
            switch self {
            case .scan: return "Scan"
            case .routine: return "Routine"
            case .progress: return "Progress"
            }
        }

        var icon: String {
            switch self {
            case .scan: return "faceid"
            case .routine: return "checklist"
            case .progress: return "chart.line.uptrend.xyaxis"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScanRecord.date, order: .reverse) private var scans: [ScanRecord]

    @State private var tab: Tab = .scan
    @State private var showFlow = false
    @State private var showSettings = false
    @State private var autoLaunched = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .scan:
                    DermiqScanHome(
                        scans: scans,
                        onScan: { startScan() },
                        onSettings: { showSettings = true }
                    )
                case .routine:
                    DermiqRoutineTab { startScan() }
                case .progress:
                    DermiqProgressTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabBar
        }
        .background(DQColor.background.ignoresSafeArea())
        .dermiqBadgeAwards()
        .sheet(isPresented: $showSettings) {
            DermiqSettingsView()
        }
        .fullScreenCover(isPresented: $showFlow) {
            DermiqScanFlowView(previousScan: scans.first) { planCreated in
                showFlow = false
                if planCreated { tab = .routine }
                // Award scan badges once the cover is gone, so the popup
                // lands on the shell — never on top of the paywall.
                Task {
                    try? await Task.sleep(for: .milliseconds(700))
                    BadgeCenter.shared.evaluateScanMilestones(context: modelContext)
                }
            }
        }
        .task {
            // Onboarding hands off straight into Guided Capture: if the user
            // arrives with zero scans, open the flow at the moment of maximum
            // motivation instead of parking them on a home screen.
            guard !autoLaunched, scans.isEmpty else { return }
            autoLaunched = true
            try? await Task.sleep(for: .milliseconds(450))
            showFlow = true
        }
    }

    private func startScan() {
        Haptics.fire(.selection)
        showFlow = true
    }

    private var tabBar: some View {
        HStack {
            ForEach(Tab.allCases, id: \.rawValue) { item in
                Button {
                    Haptics.fire(.selection)
                    withAnimation(VMotion.snappy) { tab = item }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.icon)
                            .font(.system(size: 19, weight: tab == item ? .semibold : .regular))
                        Text(item.title)
                            .font(DQFont.micro)
                    }
                    .foregroundStyle(tab == item ? DQColor.accentBright : DQColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            DQColor.surface.opacity(0.94),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
    }
}

// ============================================================
// MARK: — Screen 1: Scan Home
// ============================================================

/// Full-bleed dark screen: rotating scan portal, primary CTA, and (when past
/// scans exist) a horizontal score-history strip.
struct DermiqScanHome: View {
    let scans: [ScanRecord]
    let onScan: () -> Void
    let onSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text("VÉRITÉ")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .tracking(5)
                    .foregroundStyle(DQColor.textPrimary)
                Spacer()
                if let latest = scans.first {
                    HStack(spacing: 5) {
                        Text("LAST")
                            .font(DQFont.mono(9, weight: .semibold))
                            .foregroundStyle(DQColor.textSecondary)
                            .tracking(1.5)
                        Text(verbatim: "\(latest.overall)")
                            .font(DQFont.mono(15, weight: .bold))
                            .foregroundStyle(DQColor.accentBright)
                    }
                }
                Button {
                    Haptics.fire(.selection)
                    onSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DQColor.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(DQColor.surface, in: Circle())
                        .overlay(Circle().strokeBorder(DQColor.stroke, lineWidth: 1))
                }
                .accessibilityLabel("Settings")
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)

            Spacer()

            DQScanPortal()
                .frame(width: 280, height: 280)
                .onTapGesture { onScan() }

            Spacer()

            VStack(spacing: 20) {
                DQPrimaryButton(title: "Scan your skin", systemImage: "faceid") { onScan() }
                    .padding(.horizontal, 24)

                if !scans.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(scans, id: \.id) { scan in
                                DQHistoryChip(date: scan.date, overall: scan.overall)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .padding(.bottom, 96)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DQColor.background.ignoresSafeArea())
    }
}
