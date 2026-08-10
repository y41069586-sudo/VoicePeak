import SwiftUI

// ============================================================
// MARK: — Pre-scan questionnaire (2 quick questions)
// ============================================================
//
// Shown when the user taps "Scan now", before the capture guide. The answers
// feed RoutineBuilder so the plan visibly reflects what the user just said —
// this is what makes the routine feel authored, not templated. Answers persist
// and prefill on rescans.

struct DermiqPreScanQuiz: View {
    let onDone: (SkinPrefs) -> Void
    let onCancel: () -> Void

    @State private var feel: SkinFeel?
    @State private var concern: SkinConcernNow?
    @State private var question = 0   // 0 → feel, 1 → concern

    var body: some View {
        VStack(spacing: 0) {
            header

            // Progress: two thin segments.
            HStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { i in
                    Capsule()
                        .fill(i <= question ? DQColor.accent : DQColor.stroke)
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .animation(VMotion.gentle, value: question)

            Spacer(minLength: 12)

            Group {
                if question == 0 {
                    questionBlock(
                        title: "How does your skin usually feel?",
                        subtitle: "Steers your base products — cleanser and moisturizer."
                    ) {
                        ForEach(SkinFeel.allCases) { option in
                            choiceRow(
                                icon: option.icon,
                                label: option.displayName,
                                selected: feel == option
                            ) {
                                feel = option
                                advanceSoon(to: 1)
                            }
                        }
                    }
                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
                } else {
                    questionBlock(
                        title: "What describes it best right now?",
                        subtitle: "Your plan tackles this first."
                    ) {
                        ForEach(SkinConcernNow.allCases) { option in
                            choiceRow(
                                icon: option.icon,
                                label: option.displayName,
                                selected: concern == option
                            ) {
                                concern = option
                                finishSoon()
                            }
                        }
                    }
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .trailing).combined(with: .opacity)))
                }
            }
            .animation(VMotion.snappy, value: question)

            Spacer(minLength: 20)
        }
        .background(DQColor.background.ignoresSafeArea())
        .onAppear {
            // Prefill from the last scan — returning users just confirm.
            if let saved = SkinPrefs.load() {
                feel = saved.feel
                concern = saved.concern
            }
        }
    }

    // MARK: Pieces

    private var header: some View {
        HStack {
            Button {
                Haptics.fire(.selection)
                if question == 1 { withAnimation(VMotion.snappy) { question = 0 } }
                else { onCancel() }
            } label: {
                Image(systemName: question == 1 ? "chevron.left" : "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DQColor.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(DQColor.surface, in: Circle())
                    .overlay(Circle().strokeBorder(DQColor.stroke, lineWidth: 1))
            }
            Spacer()
            Text("QUICK CHECK · \(question + 1)/2")
                .font(DQFont.mono(10, weight: .semibold))
                .tracking(2)
                .foregroundStyle(DQColor.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private func questionBlock<Content: View>(
        title: String, subtitle: String, @ViewBuilder rows: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(DQColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(LocalizedStringKey(subtitle))
                .font(DQFont.caption)
                .foregroundStyle(DQColor.textSecondary)
            VStack(spacing: 10) { rows() }
                .padding(.top, 14)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func choiceRow(icon: String, label: String, selected: Bool,
                           action: @escaping () -> Void) -> some View {
        Button {
            Haptics.fire(.selection)
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selected ? .white : DQColor.accentBright)
                    .frame(width: 34, height: 34)
                    .background(selected ? DQColor.accent : DQColor.accentSoft, in: Circle())
                Text(LocalizedStringKey(label))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(DQColor.textPrimary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(DQColor.accentBright)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(DQColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? DQColor.accent : DQColor.stroke,
                                  lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(PressableStyle())
        .animation(VMotion.snappy, value: selected)
    }

    // MARK: Flow

    private func advanceSoon(to next: Int) {
        Task {
            try? await Task.sleep(for: .milliseconds(260))
            withAnimation(VMotion.snappy) { question = next }
        }
    }

    private func finishSoon() {
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard let feel, let concern else { return }
            let prefs = SkinPrefs(feel: feel, concern: concern)
            prefs.save()
            Haptics.fire(.capture)
            RampAnalytics.track("prescan_quiz_done", [
                "feel": feel.rawValue, "concern": concern.rawValue,
            ])
            onDone(prefs)
        }
    }
}
