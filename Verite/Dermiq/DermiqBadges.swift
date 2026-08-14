import SwiftUI
import SwiftData

// ============================================================
// MARK: — Badge definitions
// ============================================================

/// The gamification badges. Earning is monotonic — once earned, never lost
/// (no punishment mechanics, consistent with the routine design).
enum DermiqBadge: String, CaseIterable, Identifiable {
    case firstScan
    case dayOne
    case perfectDay
    case streak3
    case streak7
    case fullRamp
    case theDelta
    case plusFiveClub

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstScan:    return "First Look"
        case .dayOne:       return "Day One"
        case .perfectDay:   return "Perfect Day"
        case .streak3:      return "3-Day Streak"
        case .streak7:      return "7-Day Streak"
        case .fullRamp:     return "The Full Ramp"
        case .theDelta:     return "The Delta"
        case .plusFiveClub: return "+5 Club"
        }
    }

    var caption: String {
        switch self {
        case .firstScan:    return "You faced the honest number."
        case .dayOne:       return "First routine block completed."
        case .perfectDay:   return "AM and PM — both done."
        case .streak3:      return "Three days in a row."
        case .streak7:      return "A full week, no gaps."
        case .fullRamp:     return "All 14 days completed."
        case .theDelta:     return "First rescan done. Now it's data."
        case .plusFiveClub: return "Score up 5+ points."
        }
    }

    var icon: String {
        switch self {
        case .firstScan:    return "faceid"
        case .dayOne:       return "checkmark.circle"
        case .perfectDay:   return "sparkles"
        case .streak3:      return "flame"
        case .streak7:      return "flame.fill"
        case .fullRamp:     return "calendar.badge.checkmark"
        case .theDelta:     return "arrow.up.right"
        case .plusFiveClub: return "chart.line.uptrend.xyaxis"
        }
    }
}

// ============================================================
// MARK: — Badge center (award state + popup queue)
// ============================================================

/// Owns earned state (UserDefaults JSON) and the queue of freshly earned
/// badges the award popup presents one at a time.
@Observable
@MainActor
final class BadgeCenter {
    static let shared = BadgeCenter()

    private(set) var earned: [String: Date]
    /// Freshly earned badges waiting for their popup moment.
    private(set) var pending: [DermiqBadge] = []

    private static let storageKey = "dermiq.badges.earned"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let stored = try? JSONDecoder().decode([String: Date].self, from: data) {
            earned = stored
        } else {
            earned = [:]
        }
    }

    func isEarned(_ badge: DermiqBadge) -> Bool {
        earned[badge.rawValue] != nil
    }

    var earnedCount: Int { earned.count }

    /// Awards once; repeat calls are no-ops.
    func award(_ badge: DermiqBadge) {
        guard earned[badge.rawValue] == nil else { return }
        earned[badge.rawValue] = Date()
        save()
        pending.append(badge)
        RampAnalytics.track("badge_earned", ["badge": badge.rawValue])
    }

    func dismissCurrent() {
        guard !pending.isEmpty else { return }
        pending.removeFirst()
    }

    /// Delete-account support: wipes all earned badges.
    func resetAll() {
        earned = [:]
        pending = []
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(earned) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    // MARK: Milestone evaluation

    /// Scan-related badges, evaluated when a scan flow finishes (so the popup
    /// lands on the shell, never on top of the paywall).
    func evaluateScanMilestones(context: ModelContext) {
        let descriptor = FetchDescriptor<ScanRecord>(sortBy: [SortDescriptor(\.date, order: .forward)])
        let scans = (try? context.fetch(descriptor)) ?? []
        guard let latest = scans.last else { return }

        if scans.count == 1 { award(.firstScan) }
        if latest.isRescan { award(.theDelta) }
        if scans.count >= 2, latest.overall - scans[scans.count - 2].overall >= 5 {
            award(.plusFiveClub)
        }
    }

    /// Routine-related badges, evaluated after a step toggle.
    func evaluateRoutineMilestones(plan: RoutinePlan, day: Int) {
        if plan.blockComplete(day: day, .am) || plan.blockComplete(day: day, .pm) {
            award(.dayOne)
        }
        if plan.dayComplete(day) { award(.perfectDay) }
        if plan.streak >= 3 { award(.streak3) }
        if plan.streak >= 7 { award(.streak7) }
        if (1...14).allSatisfy({ plan.dayComplete($0) }) { award(.fullRamp) }
    }
}

// ============================================================
// MARK: — Award popup
// ============================================================

/// Full-screen award moment: dimmed stage, ring draws in, icon pops with a
/// spring, sparkles burst once. One badge at a time; tap continues.
struct DermiqBadgeAwardView: View {
    let badge: DermiqBadge
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ringProgress: Double = 0
    @State private var iconShown = false
    @State private var textShown = false
    @State private var sparkle = false

    var body: some View {
        ZStack {
            DQColor.background.opacity(0.86).ignoresSafeArea()

            VStack(spacing: 22) {
                ZStack {
                    DermiqBadgeSparkles(fire: sparkle)
                    DQScoreRing(progress: ringProgress, lineWidth: 5)
                        .frame(width: 128, height: 128)
                    Image(systemName: badge.icon)
                        .font(.system(size: 46, weight: .light))
                        .foregroundStyle(DQColor.accentBright)
                        .scaleEffect(iconShown ? 1 : 0.2)
                        .opacity(iconShown ? 1 : 0)
                        .shadow(color: DQColor.accentEdge.opacity(0.8), radius: 14)
                }
                .frame(height: 170)

                VStack(spacing: 7) {
                    Text("BADGE EARNED")
                        .font(DQFont.mono(11, weight: .semibold))
                        .foregroundStyle(DQColor.accentBright)
                        .tracking(3)
                    Text(LocalizedStringKey(badge.title))
                        .font(DQFont.title)
                        .foregroundStyle(DQColor.textPrimary)
                    Text(LocalizedStringKey(badge.caption))
                        .font(DQFont.body)
                        .foregroundStyle(DQColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .opacity(textShown ? 1 : 0)
                .offset(y: textShown ? 0 : 10)

                DQPrimaryButton(title: "Nice") { onDismiss() }
                    .frame(width: 190)
                    .opacity(textShown ? 1 : 0)
            }
            .padding(.vertical, 34)
            .padding(.horizontal, 26)
            .background(
                DQColor.surface,
                in: RoundedRectangle(cornerRadius: DQRadius.sheet, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DQRadius.sheet, style: .continuous)
                    .strokeBorder(DQColor.stroke, lineWidth: 1)
            )
            .padding(.horizontal, 36)
            .shadow(color: DQColor.accentEdge.opacity(0.25), radius: 40)
        }
        .task(id: badge.rawValue) { await play() }
    }

    private func play() async {
        ringProgress = 0; iconShown = false; textShown = false; sparkle = false
        Haptics.fire(.verdictReveal)

        if reduceMotion {
            ringProgress = 1; iconShown = true; textShown = true
            return
        }

        withAnimation(.easeOut(duration: 0.7)) { ringProgress = 1 }
        try? await Task.sleep(for: .milliseconds(280))
        withAnimation(.spring(response: 0.38, dampingFraction: 0.55)) { iconShown = true }
        sparkle = true
        Haptics.fire(.milestone)
        try? await Task.sleep(for: .milliseconds(240))
        withAnimation(VMotion.gentle) { textShown = true }
    }
}

/// One-shot burst of sparkle dots radiating from the badge ring.
private struct DermiqBadgeSparkles: View {
    let fire: Bool

    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { index in
                let angle = Double(index) / 10 * 2 * .pi
                let size: CGFloat = index % 3 == 0 ? 6 : 4
                Circle()
                    .fill(index % 2 == 0 ? DQColor.accentBright : DQColor.deltaUp)
                    .frame(width: size, height: size)
                    .offset(
                        x: cos(angle) * (fire ? 105 : 40),
                        y: sin(angle) * (fire ? 105 : 40)
                    )
                    .opacity(fire ? 0 : 0.9)
                    .animation(
                        .easeOut(duration: 0.8).delay(Double(index) * 0.015),
                        value: fire
                    )
            }
        }
        .allowsHitTesting(false)
    }
}

// ============================================================
// MARK: — Overlay mounting
// ============================================================

private struct DermiqBadgeAwardOverlay: ViewModifier {
    // Computed, not stored: `.shared` is MainActor-isolated and body is the
    // only MainActor-guaranteed access point.
    private var center: BadgeCenter { .shared }

    func body(content: Content) -> some View {
        content.overlay {
            if let badge = center.pending.first {
                DermiqBadgeAwardView(badge: badge) {
                    center.dismissCurrent()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
        }
        .animation(VMotion.gentle, value: center.pending.count)
    }
}

extension View {
    /// Presents queued badge-award popups above this view.
    func dermiqBadgeAwards() -> some View { modifier(DermiqBadgeAwardOverlay()) }
}

// ============================================================
// MARK: — Badges grid (Progress tab section)
// ============================================================

struct DermiqBadgesSection: View {
    private var center: BadgeCenter { .shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("BADGES")
                    .font(DQFont.mono(11, weight: .semibold))
                    .foregroundStyle(DQColor.textSecondary)
                    .tracking(2)
                Spacer()
                Text(verbatim: "\(center.earnedCount)/\(DermiqBadge.allCases.count)")
                    .font(DQFont.mono(11, weight: .semibold))
                    .foregroundStyle(DQColor.accentBright)
            }
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                spacing: 12
            ) {
                ForEach(DermiqBadge.allCases) { badge in
                    DermiqBadgeTile(badge: badge, earned: center.isEarned(badge))
                }
            }
        }
    }
}

private struct DermiqBadgeTile: View {
    let badge: DermiqBadge
    let earned: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(earned ? AnyShapeStyle(DQColor.accentGradient)
                                 : AnyShapeStyle(DQColor.surfaceElevated))
                    .frame(width: 52, height: 52)
                Image(systemName: earned ? badge.icon : "lock.fill")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(earned ? DQColor.textPrimary : DQColor.textSecondary.opacity(0.6))
            }
            .shadow(color: DQColor.accentEdge.opacity(earned ? 0.4 : 0), radius: 10)
            Text(LocalizedStringKey(badge.title))
                .font(DQFont.micro)
                .foregroundStyle(earned ? DQColor.textPrimary : DQColor.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(DQColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1)
        )
        .accessibilityLabel(Text(verbatim: "\(badge.title): \(earned ? String(localized: "earned") : String(localized: "locked"))"))
    }
}
