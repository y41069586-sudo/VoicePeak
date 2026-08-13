import SwiftUI
import SwiftData

// ============================================================
// MARK: — Compare screen (you vs a friend, real charts)
// ============================================================
//
// Shows two real result charts — round photo + the two-column metric grid —
// with a segmented toggle to flip between yours and theirs, and a banner for
// who leads on overall. If you haven't scanned yet, it asks you to scan first
// (that's your card); once you have one, both cards are here and you can send
// yours back so your friend sees the same face-off.

struct CompareView: View {
    let opponent: ComparePayload
    /// Called when the receiver has no scan yet and taps "Scan my face".
    var onScanFirst: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ScanRecord.date, order: .reverse) private var scans: [ScanRecord]
    @Query private var profiles: [UserProfile]

    /// false → showing the opponent's card; true → showing mine.
    @State private var showingMine = true

    private var myScan: ScanRecord? { scans.first }
    private var myName: String {
        let n = profiles.first?.displayName ?? ""
        return n.isEmpty ? String(localized: "You") : n
    }

    var body: some View {
        NavigationStack {
            Group {
                if let scan = myScan, let analysis = scan.analysis {
                    loaded(scan: scan, analysis: analysis)
                } else {
                    scanFirst
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DQColor.background.ignoresSafeArea())
            .navigationTitle("Skin Duel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(DQColor.accentBright)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: Loaded — both cards present

    @ViewBuilder
    private func loaded(scan: ScanRecord, analysis: DermiqAnalysis) -> some View {
        let mineOverall = analysis.overall
        let theirs = opponent.overall

        ScrollView {
            VStack(spacing: 18) {
                winnerBanner(mine: mineOverall, theirs: theirs)

                segmented

                if showingMine {
                    chartCard(name: myName,
                              overall: mineOverall,
                              subValue: { analysis.subScore(for: $0)?.value },
                              photo: DermiqImageStore.load(scan.photoFilename),
                              lead: mineOverall > theirs)
                        .transition(.opacity)
                } else {
                    chartCard(name: opponent.name,
                              overall: theirs,
                              subValue: { opponent.value(for: $0) },
                              photo: opponent.thumbImage,
                              lead: theirs > mineOverall)
                        .transition(.opacity)
                }

                // Send my card back so the friend sees the same result.
                if let url = CompareLink.url(for: ComparePayload.mine(
                    name: myName, analysis: analysis,
                    photo: DermiqImageStore.load(scan.photoFilename))) {
                    ShareLink(item: url,
                              message: Text("Here's my skin score — see how yours compares 👇")) {
                        Label("Send my card back", systemImage: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(DQColor.accentBright,
                                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(20)
        }
        .animation(VMotion.gentle, value: showingMine)
    }

    private func winnerBanner(mine: Int, theirs: Int) -> some View {
        let title: LocalizedStringKey
        let icon: String
        if mine > theirs { title = "You're ahead"; icon = "crown.fill" }
        else if theirs > mine { title = "\(opponent.name) is ahead"; icon = "flame.fill" }
        else { title = "It's a tie"; icon = "equal.circle.fill" }
        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(DQColor.accentBright)
            Text(title)
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(DQColor.textPrimary)
            Spacer()
            Text(verbatim: "\(mine) · \(theirs)")
                .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(DQColor.textSecondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(DQColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(DQColor.stroke, lineWidth: 1))
    }

    private var segmented: some View {
        HStack(spacing: 0) {
            segment(title: myName, active: showingMine) { showingMine = true }
            segment(title: opponent.name, active: !showingMine) { showingMine = false }
        }
        .padding(4)
        .background(DQColor.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(DQColor.stroke, lineWidth: 1))
    }

    private func segment(title: String, active: Bool, _ tap: @escaping () -> Void) -> some View {
        Button {
            Haptics.fire(.selection)
            withAnimation(VMotion.snappy) { tap() }
        } label: {
            Text(verbatim: title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(active ? .white : DQColor.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 40)
                // Solid, not `accentGradient`: the gradient's light end is the
                // sand CTA colour, and white type on that is 2.6:1. The deep
                // end alone carries white at 5.5:1.
                .background(active ? AnyShapeStyle(DQColor.accentBright) : AnyShapeStyle(.clear),
                            in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: The chart card (round photo + two columns) — the real look

    private func chartCard(name: String, overall: Int,
                           subValue: @escaping (DermiqCategory) -> Int?,
                           photo: UIImage?, lead: Bool) -> some View {
        let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
        return ZStack(alignment: .top) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                metricCell("Overall", overall, lead: true)
                ForEach(DermiqCategory.allCases) { cat in
                    if let v = subValue(cat) {
                        metricCell(cat.displayName, v, lead: false)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 70)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            .background(DQColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(lead ? DQColor.accent.opacity(0.5) : DQColor.stroke, lineWidth: lead ? 1.5 : 1))

            avatar(photo)
                .offset(y: -52)
        }
        .padding(.top, 52)
    }

    private func metricCell(_ label: String, _ value: Int, lead: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(label))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(DQColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(verbatim: "\(value)")
                .font(.system(size: 25, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(lead ? DQColor.accentBright : DQColor.textPrimary)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(DQColor.stroke.opacity(0.7))
                    Capsule()
                        .fill(lead ? AnyShapeStyle(DQColor.accentGradient) : AnyShapeStyle(DQColor.accent))
                        .frame(width: proxy.size.width * CGFloat(value) / 100)
                }
            }
            .frame(height: 6)
        }
    }

    private func avatar(_ photo: UIImage?) -> some View {
        Group {
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill()
            } else {
                ZStack {
                    DQColor.accentSoft
                    Image(systemName: "person.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(DQColor.accentBright.opacity(0.7))
                }
            }
        }
        .frame(width: 104, height: 104)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(DQColor.surface, lineWidth: 4))
        .overlay(Circle().strokeBorder(DQColor.accentSoft, lineWidth: 4).padding(-4))
        .shadow(color: DQColor.accent.opacity(0.28), radius: 14, y: 8)
    }

    // MARK: No scan yet

    private var scanFirst: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(DQColor.accentBright)
            Text("\(opponent.name) challenged you")
                .font(.system(size: 21, weight: .heavy, design: .rounded))
                .foregroundStyle(DQColor.textPrimary)
                .multilineTextAlignment(.center)
            Text("Scan your face to see how your skin scores stack up.")
                .font(DQFont.caption)
                .foregroundStyle(DQColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 30)
            Button {
                dismiss()
                onScanFirst()
            } label: {
                Label("Scan my face", systemImage: "camera.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(DQColor.accentBright,
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(PressableStyle())
            .padding(.horizontal, 30)
            Spacer()
        }
    }
}
