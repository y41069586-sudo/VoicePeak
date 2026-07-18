import SwiftUI
import SwiftData

// ============================================================
// MARK: — Glow-Up Reel sheet
// ============================================================
//
// Entry: Progress tab, once ≥2 scans carry photos. Shows which scans go into
// the video, exports on-device with a progress ring, then hands the .mp4 to
// the share sheet — cut for TikTok/Reels (1080×1920).

/// Drives one export. `@MainActor` — the heavy composing runs detached and
/// reports back here.
@Observable
@MainActor
final class ReelExportModel {
    var progress: Double = 0
    var url: URL?
    var exporting = false
    var failed = false

    func start(frames: [ReelFrame]) {
        guard !exporting else { return }
        exporting = true
        failed = false
        url = nil
        progress = 0
        // A MainActor Task; `compose` is nonisolated async, so its heavy render
        // loop runs OFF the main actor, and we resume back here to publish the
        // result. `report` is a plain @Sendable closure that hops to main — no
        // nested weak-self captures (which Swift 6 rejects in concurrent code).
        Task { [weak self] in
            let report: @Sendable (Double) -> Void = { p in
                Task { @MainActor in self?.progress = p }
            }
            do {
                let out = try await GlowUpReelComposer.compose(frames: frames, progress: report)
                self?.url = out
                self?.exporting = false
            } catch {
                self?.failed = true
                self?.exporting = false
            }
        }
    }
}

struct GlowUpReelSheet: View {
    /// Ascending by date; every record has a photo (filtered by the caller).
    let scans: [ScanRecord]

    @Environment(\.dismiss) private var dismiss
    @State private var model = ReelExportModel()
    @State private var tooFewFrames = false

    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(DQColor.stroke).frame(width: 40, height: 5).padding(.top, 10)

            VStack(spacing: 6) {
                Text("Glow-Up Reel")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(DQColor.textPrimary)
                Text("Your scans, cut into a share-ready video — score count-up included.")
                    .font(DQFont.caption)
                    .foregroundStyle(DQColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            photoStrip

            HStack(spacing: 14) {
                factChip(icon: "rectangle.portrait", text: "9:16")
                factChip(icon: "timer", text: "~\(estimatedSeconds)s")
                factChip(icon: "iphone", text: "On-device")
            }

            Spacer(minLength: 0)

            if model.exporting {
                exportingView
            } else if let url = model.url {
                doneView(url)
            } else {
                DQPrimaryButton(title: "Create my reel", systemImage: "film.fill") {
                    startExport()
                }
                .padding(.horizontal, 24)
                if model.failed {
                    Text("Export failed — try again.")
                        .font(DQFont.micro)
                        .foregroundStyle(DQColor.deltaDown)
                }
                if tooFewFrames {
                    Text("You need at least 2 scans with photos to make a reel.")
                        .font(DQFont.micro)
                        .foregroundStyle(DQColor.deltaDown)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
        }
        .padding(.bottom, 26)
        .background(DQColor.background.ignoresSafeArea())
        .presentationDetents([.large])
    }

    // MARK: Pieces

    private var photoStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Array(scans.enumerated()), id: \.element.id) { index, scan in
                    VStack(spacing: 4) {
                        Group {
                            if let image = DermiqImageStore.load(scan.photoFilename) {
                                Image(uiImage: image).resizable().scaledToFill()
                            } else {
                                DQColor.accentSoft
                            }
                        }
                        .frame(width: 64, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(DQColor.stroke, lineWidth: 1)
                        )
                        Text(verbatim: dayLabel(for: index))
                            .font(DQFont.mono(9, weight: .semibold))
                            .foregroundStyle(DQColor.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .scrollIndicators(.hidden)
    }

    private func factChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            // LocalizedStringKey: "On-device" translates; "9:16"/"~8s" fall
            // through to their own literal, which is exactly what we want.
            Text(LocalizedStringKey(text)).font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(DQColor.textSecondary)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(DQColor.surfaceElevated, in: Capsule())
    }

    private var exportingView: some View {
        VStack(spacing: 12) {
            ZStack {
                DQScoreRing(progress: model.progress, lineWidth: 8)
                    .frame(width: 72, height: 72)
                Text(verbatim: "\(Int(model.progress * 100))%")
                    .font(.system(size: 16, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(DQColor.accentBright)
            }
            Text("Rendering your reel…")
                .font(DQFont.caption)
                .foregroundStyle(DQColor.textSecondary)
        }
        .padding(.bottom, 12)
    }

    private func doneView(_ url: URL) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(DQColor.deltaUp)
                Text("Your reel is ready")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(DQColor.textPrimary)
            }
            ShareLink(item: url) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share video")
                }
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(DQColor.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(.horizontal, 24)
            Button {
                Haptics.fire(.selection)
                startExport()
            } label: {
                Text("Render again")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(DQColor.accentBright)
            }
        }
    }

    // MARK: Data

    private var estimatedSeconds: Int {
        // Mirrors the composer's timeline: intro 1.8 + middles 0.8 + finale 2.8 + outro 1.6.
        let middles = max(scans.count - 2, 0)
        return Int((1.8 + Double(middles) * 0.8 + 2.8 + 1.6).rounded())
    }

    private func dayLabel(for index: Int) -> String {
        guard let first = scans.first else { return String(localized: "DAY \(1)") }
        let days = Calendar.current.dateComponents(
            [.day], from: Calendar.current.startOfDay(for: first.date),
            to: Calendar.current.startOfDay(for: scans[index].date)
        ).day ?? 0
        return String(localized: "DAY \(days + 1)")
    }

    private func startExport() {
        let frames: [ReelFrame] = scans.enumerated().compactMap { index, scan in
            guard let image = DermiqImageStore.load(scan.photoFilename) else { return nil }
            return ReelFrame(image: image, dayLabel: dayLabel(for: index), score: scan.overall)
        }
        guard frames.count >= 2 else {
            tooFewFrames = true
            Haptics.fire(.transition)
            return
        }
        tooFewFrames = false
        Haptics.fire(.capture)
        model.start(frames: frames)
        RampAnalytics.track("reel_export_started", ["scans": String(frames.count)])
    }
}
