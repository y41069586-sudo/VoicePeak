import SwiftUI
import SwiftData
import UIKit

// ============================================================
// MARK: — v2 shell: Scan / Routine / Progress
// ============================================================

struct DermiqTabShell: View {
    enum Tab: String, CaseIterable {
        case scan, routine, progress

        var title: String {
            switch self {
            case .scan: return "Home"
            case .routine: return "Routine"
            case .progress: return "Progress"
            }
        }

        var icon: String {
            switch self {
            case .scan: return "house.fill"
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
                        onSettings: { showSettings = true },
                        onRoutine: { withAnimation(VMotion.snappy) { tab = .routine } },
                        onProgress: { withAnimation(VMotion.snappy) { tab = .progress } }
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
        .onAppear {
            // Onboarding hands off straight into the camera: with zero scans,
            // open the capture flow IMMEDIATELY and without the cover's slide
            // animation, so the home dashboard never flashes behind it.
            guard !autoLaunched, scans.isEmpty else { return }
            autoLaunched = true
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { showFlow = true }
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
// MARK: — Screen 1: Home (the daily dashboard)
// ============================================================

/// The home tab is a real dashboard, not just a scan button: a personal
/// greeting, the latest score with its delta, today's ritual progress, a
/// daily tip and the score history — with the scan CTA always one thumb away.
/// Zero scans → a focused first-scan hero instead.
struct DermiqScanHome: View {
    let scans: [ScanRecord]
    let onScan: () -> Void
    let onSettings: () -> Void
    var onRoutine: () -> Void = {}
    var onProgress: () -> Void = {}

    @Query private var profiles: [UserProfile]

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let base: String
        switch hour {
        case 5..<12:  base = "Good morning"
        case 12..<18: base = "Good afternoon"
        default:      base = "Good evening"
        }
        if let name = profiles.first?.displayName, !name.isEmpty {
            return "\(base), \(name)"
        }
        return base
    }

    /// One gentle, rotating tip a day — deterministic by day-of-year.
    private var dailyTip: String {
        let tips = [
            "SPF is the single biggest lever for your score — even on cloudy days.",
            "Glow follows sleep. Tonight's 8 hours show up in Thursday's scan.",
            "Consistency beats intensity: two gentle steps daily outwork a weekly overhaul.",
            "Hydration reads instantly on camera — water before coffee.",
            "Redness calms fastest when you skip hot water on your face.",
            "Texture changes are slow and real — trust the 14-day rhythm.",
            "Your evening cleanse matters more than any serum layered on top.",
        ]
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        return tips[day % tips.count]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            home
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DQColor.background.ignoresSafeArea())
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 14) {
            Text(greeting)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(DQColor.textSecondary)
            Spacer()
            Button {
                Haptics.fire(.selection)
                onSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DQColor.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(DQColor.surface, in: Circle())
                    .overlay(Circle().strokeBorder(DQColor.stroke, lineWidth: 1))
            }
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
    }

    // MARK: Home (one focused scan card — Routine & Progress live in the tab bar)

    private var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(homeHeadline)
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(DQColor.textPrimary)
                        .lineSpacing(1)
                    Text(homeSubhead)
                        .font(DQFont.body)
                        .foregroundStyle(DQColor.textSecondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                scanCard
                    .padding(.horizontal, 24)

                if let latest = scans.first {
                    lastReadingRow(latest)
                        .padding(.horizontal, 24)
                }

                tipCard
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
    }

    /// Time-aware, non-cheesy headline (replaces "Ready to glow?").
    private var homeHeadline: String {
        scans.isEmpty ? "Let's read\nyour skin." : "Your skin,\ntoday."
    }

    private var homeSubhead: String {
        scans.isEmpty
            ? "One photo — an honest score in under a minute."
            : "One scan to see today's number and where it's headed."
    }

    /// The single home card: a designed viewfinder visual (your photo once you
    /// have one), a clear line, and the scan CTA. Routine and Progress are one
    /// tap away in the tab bar, so Home stays focused on the next scan.
    private var scanCard: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 26)
            DeckScanVisual(photo: scans.first.flatMap { DermiqImageStore.load($0.photoFilename) })
                .frame(height: 170)
            Spacer().frame(height: 20)
            Text(scans.isEmpty ? "First Skin Scan" : "New Skin Scan")
                .font(.system(size: 23, weight: .heavy, design: .rounded))
                .foregroundStyle(DQColor.textPrimary)
            Text("One photo. An honest 0–100 score across 7 metrics.")
                .font(DQFont.caption)
                .foregroundStyle(DQColor.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)
                .padding(.top, 6)
            Spacer().frame(height: 20)
            DQPrimaryButton(title: scans.isEmpty ? "Start scan" : "New scan",
                            systemImage: "camera.fill") { onScan() }
                .padding(.horizontal, 20)
            Spacer().frame(height: 22)
        }
        .frame(maxWidth: .infinity)
        .background(DQColor.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1)
        )
        .shadow(color: DQColor.accent.opacity(0.08), radius: 18, y: 8)
    }

    /// One slim personal row under the deck: your photo, last score, delta,
    /// projected potential — a tap opens Progress.
    private func lastReadingRow(_ latest: ScanRecord) -> some View {
        let previous = scans.dropFirst().first
        let delta = previous.map { latest.overall - $0.overall }
        let potential = latest.analysis.map { DermiqProjection.project($0).overall }
        return Button {
            Haptics.fire(.selection)
            onProgress()
        } label: {
            HStack(spacing: 12) {
                Group {
                    if let image = DermiqImageStore.load(latest.photoFilename) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        ZStack {
                            DQColor.accentSoft
                            Image(systemName: "faceid")
                                .font(.system(size: 15, weight: .light))
                                .foregroundStyle(DQColor.accentBright)
                        }
                    }
                }
                .frame(width: 42, height: 42)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(DQColor.accentSoft, lineWidth: 2))

                VStack(alignment: .leading, spacing: 1) {
                    Text("LAST READING")
                        .font(DQFont.mono(9, weight: .semibold))
                        .foregroundStyle(DQColor.textSecondary)
                        .tracking(1.5)
                    HStack(spacing: 6) {
                        Text(verbatim: "\(latest.overall)")
                            .font(.system(size: 20, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(DQColor.textPrimary)
                        if let delta, delta != 0 {
                            HStack(spacing: 2) {
                                Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                                    .font(.system(size: 9, weight: .bold))
                                Text(verbatim: "\(abs(delta))")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(delta > 0 ? DQColor.deltaUp : DQColor.deltaDown)
                        }
                    }
                }
                Spacer()
                if let potential, potential > latest.overall {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("POTENTIAL · EST.")
                            .font(DQFont.mono(9, weight: .semibold))
                            .foregroundStyle(DQColor.textSecondary)
                            .tracking(1.5)
                        Text(verbatim: "\(potential)")
                            .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(DQColor.accentBright)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DQColor.textSecondary)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DQColor.surface, in: RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous)
                    .strokeBorder(DQColor.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle())
    }

    private var tipCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.max")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DQColor.accentBright)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text("TODAY'S TIP")
                    .font(DQFont.mono(9, weight: .semibold))
                    .foregroundStyle(DQColor.textSecondary)
                    .tracking(1.5)
                Text(dailyTip)
                    .font(DQFont.caption)
                    .foregroundStyle(DQColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DQColor.surfaceElevated, in: RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1)
        )
    }
}

// ============================================================
// MARK: — Deck visuals (designed, data-driven — no icon-in-a-disc)
// ============================================================

/// Scan card visual: a soft viewfinder with corner brackets and a scan line.
/// Shows YOUR latest capture when one exists; a friendly face sketch before.
private struct DeckScanVisual: View {
    let photo: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DQColor.accentSoft.opacity(0.5))
            Group {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 96, height: 118)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    DeckFaceSketch()
                        .frame(width: 86, height: 108)
                }
            }
            DeckBrackets()
                .stroke(DQColor.accent, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .frame(width: 130, height: 146)
            LinearGradient(colors: [.clear, DQColor.accent.opacity(0.7), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: 118, height: 2.5)
                .offset(y: 12)
        }
        .frame(width: 190, height: 158)
    }
}

/// A clean, friendly face for the pre-photo state — a soft head, two lively
/// eyes with a catch-light, a hint of blush and a gentle smile. Proportional
/// (GeometryReader) so it reads as designed, not doodled.
private struct DeckFaceSketch: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                // Head — soft white fill with a rounded accent outline.
                DeckHeadShape()
                    .fill(DQColor.surface)
                DeckHeadShape()
                    .stroke(DQColor.accentBright, style: StrokeStyle(lineWidth: 3, lineJoin: .round))

                // Blush, low on the cheeks.
                blush(at: CGPoint(x: w * 0.29, y: h * 0.60), in: geo.size)
                blush(at: CGPoint(x: w * 0.71, y: h * 0.60), in: geo.size)

                // Eyes with a small catch-light.
                eye(at: CGPoint(x: w * 0.38, y: h * 0.45), in: geo.size)
                eye(at: CGPoint(x: w * 0.62, y: h * 0.45), in: geo.size)

                // Gentle smile.
                DeckSmile()
                    .stroke(DQColor.accentBright, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: w * 0.34, height: h * 0.12)
                    .position(x: w * 0.5, y: h * 0.68)
            }
        }
    }

    private func eye(at point: CGPoint, in size: CGSize) -> some View {
        ZStack {
            Ellipse()
                .fill(DQColor.accentBright)
                .frame(width: size.width * 0.085, height: size.height * 0.085)
            Circle()
                .fill(Color.white)
                .frame(width: size.width * 0.03, height: size.width * 0.03)
                .offset(x: size.width * 0.018, y: -size.height * 0.018)
        }
        .position(point)
    }

    private func blush(at point: CGPoint, in size: CGSize) -> some View {
        Ellipse()
            .fill(DQColor.accent.opacity(0.20))
            .frame(width: size.width * 0.15, height: size.height * 0.065)
            .position(point)
    }
}

/// A rounded head — wider at the temples, tapering to a soft chin.
private struct DeckHeadShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        // Right side down to a soft chin.
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                   control1: CGPoint(x: rect.minX + w * 1.06, y: rect.minY + h * 0.10),
                   control2: CGPoint(x: rect.minX + w * 0.82, y: rect.maxY))
        // Left side back up.
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                   control1: CGPoint(x: rect.minX + w * 0.18, y: rect.maxY),
                   control2: CGPoint(x: rect.minX - w * 0.06, y: rect.minY + h * 0.10))
        p.closeSubpath()
        return p
    }
}

/// Four rounded viewfinder corner brackets.
private struct DeckBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        let len = min(rect.width, rect.height) * 0.18
        let r: CGFloat = 10
        var p = Path()
        // Top-left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + len))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + len, y: rect.minY))
        // Top-right
        p.move(to: CGPoint(x: rect.maxX - len, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r),
                       control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + len))
        // Bottom-right
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - len))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - len, y: rect.maxY))
        // Bottom-left
        p.move(to: CGPoint(x: rect.minX + len, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - len))
        return p
    }
}

private struct DeckSmile: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                       control: CGPoint(x: rect.midX, y: rect.maxY + rect.height))
        return p
    }
}

