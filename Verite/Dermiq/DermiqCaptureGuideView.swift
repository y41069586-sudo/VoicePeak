import SwiftUI

// ============================================================
// MARK: — Capture guide (Do's & Don'ts, before the camera)
// ============================================================

/// The pre-scan primer, shown right before the camera opens. It sets the user
/// up for a usable photo (the single biggest driver of a good reading) with a
/// short Do's / Don'ts list and a clear Continue into capture — the UMax
/// pattern, in our own light-blue language and without borrowed example photos.
struct DermiqCaptureGuideView: View {
    let onContinue: () -> Void
    let onCancel: () -> Void

    private let dos: [(String, String)] = [
        ("eye", "Look straight at the camera"),
        ("lightbulb", "Use good, even lighting"),
        ("face.smiling", "Bare face — no makeup filter"),
    ]
    private let donts: [(String, String)] = [
        ("eyeglasses", "No hats, glasses or masks"),
        ("hand.raised", "Don’t cover your face or hairline"),
        ("camera.filters", "No beauty filters or heavy edits"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with a back/cancel.
            HStack {
                Button {
                    Haptics.fire(.selection)
                    onCancel()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DQColor.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(DQColor.surface, in: Circle())
                        .overlay(Circle().strokeBorder(DQColor.stroke, lineWidth: 1))
                }
                .accessibilityLabel("Back")
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Before your scan")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(DQColor.textPrimary)
                        Text("One clear photo is all it takes. A few quick do’s and don’ts:")
                            .font(DQFont.body)
                            .foregroundStyle(DQColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 6)

                    guideCard(title: "DO", tint: DQColor.deltaUp,
                              symbol: "checkmark.circle.fill", rows: dos)
                    guideCard(title: "DON’T", tint: DQColor.deltaDown,
                              symbol: "xmark.circle.fill", rows: donts)

                    // Privacy reassurance — the reason people hesitate to scan.
                    // Say what actually happens: the analysis provider gets the
                    // photo and drops it, but WE keep it on the device (that's
                    // what history, the compare avatar and the reel are built
                    // from). The old copy said "then discarded", which read as
                    // "the photo is gone" and contradicted both the privacy
                    // policy and the face-data answer given to App Review.
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Your photo is sent securely for analysis and isn’t kept by the analysis service. It stays on this device so you can see your progress — delete it any time in Settings.")
                            .font(DQFont.micro)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(DQColor.accentBright)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DQColor.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            DQPrimaryButton(title: "Continue", systemImage: "camera.fill") {
                onContinue()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(DQColor.background.ignoresSafeArea())
    }

    private func guideCard(title: String, tint: Color, symbol: String,
                           rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(LocalizedStringKey(title))
                .font(DQFont.mono(11, weight: .bold))
                .foregroundStyle(tint)
                .tracking(3)
            ForEach(rows, id: \.1) { row in
                HStack(spacing: 12) {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(tint)
                    Text(LocalizedStringKey(row.1))
                        .font(DQFont.headline)
                        .foregroundStyle(DQColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DQColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(DQColor.stroke, lineWidth: 1))
    }
}
