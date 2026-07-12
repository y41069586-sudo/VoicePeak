import SwiftUI

// ============================================================
// MARK: — Duel share cards (9:16, rendered to PNG for sharing)
// ============================================================

/// The invite card: "I challenge you." Screenshot-ready, carries the code and
/// a clear call to download + join.
struct DuelChallengeCard: View {
    let myName: String
    let code: String
    static let size = CGSize(width: 360, height: 640)

    var body: some View {
        ZStack {
            LinearGradient(colors: [DQColor.accent, DQColor.accentBright],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            VStack(spacing: 0) {
                Text("SKIN DUEL")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 44)

                Spacer()

                Image(systemName: "flag.checkered.2.crossed")
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 4)

                Text(myName.isEmpty ? "Someone" : myName)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 22)
                Text("challenges you to a\n14-day glow-up")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.top, 6)
                    .lineSpacing(2)

                Spacer()

                VStack(spacing: 8) {
                    Text("JOIN CODE")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(code)
                        .font(.system(size: 28, weight: .heavy, design: .rounded).monospaced())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.16), in: Capsule())
                }

                Text("Scan your skin, run the 14-day plan,\ncompare who improves most.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(.top, 20)
                    .lineSpacing(2)

                Text("Vérité")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 22)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 28)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}

/// The result card: head-to-head deltas with the winner crowned.
struct DuelResultCard: View {
    let duel: SkinDuel
    static let size = CGSize(width: 360, height: 640)

    private var iWon: Bool { duel.outcome == .win }
    private var draw: Bool { duel.outcome == .draw }

    var body: some View {
        ZStack {
            DQColor.background

            VStack(spacing: 0) {
                Text("SKIN DUEL · RESULT")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(DQColor.textSecondary)
                    .padding(.top, 40)

                Spacer()

                side(name: duel.myName.isEmpty ? "You" : duel.myName,
                     delta: duel.myDelta ?? 0,
                     winner: iWon || draw)
                    .padding(.bottom, 10)

                Text("VS")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(DQColor.textSecondary)
                    .padding(.vertical, 4)

                side(name: duel.opponentName.isEmpty ? "Rival" : duel.opponentName,
                     delta: duel.opponentDelta ?? 0,
                     winner: !iWon || draw)
                    .padding(.top, 10)

                Spacer()

                Text(draw ? "Dead heat 🤝" : (iWon ? "You won 👑" : "They edged it"))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(DQColor.textPrimary)

                Text("Vérité · 14-day Skin Duel")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(DQColor.accentBright)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 28)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    private func side(name: String, delta: Int, winner: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(winner ? DQColor.accent : DQColor.surfaceElevated)
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(winner ? .white : DQColor.textSecondary)
            }
            .frame(width: 56, height: 56)
            .overlay(alignment: .topTrailing) {
                if winner {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.24))
                        .offset(x: 6, y: -8)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(DQColor.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 13, weight: .heavy))
                    Text(verbatim: "\(delta >= 0 ? "+" : "")\(delta) pts in 14 days")
                        .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                }
                .foregroundStyle(delta >= 0 ? DQColor.deltaUp : DQColor.deltaDown)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(DQColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(winner ? DQColor.accent.opacity(0.5) : DQColor.stroke,
                              lineWidth: winner ? 2 : 1)
        )
    }
}
