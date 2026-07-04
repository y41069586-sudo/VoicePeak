import SwiftUI
import SwiftData

/// Steps through the proven routine one product at a time, with an absorb-wait
/// after actives (retinol/acids) and haptic ticks between steps.
struct RoutineTimerView: View {
    let items: [RoutineItem]

    @Environment(\.dismiss) private var dismiss
    @Query private var products: [Product]

    @State private var index = 0
    @State private var waiting = false
    @State private var waitRemaining = 0
    @State private var waitTask: Task<Void, Never>?

    private func product(_ item: RoutineItem) -> Product? {
        products.first { $0.id == item.productID }
    }

    /// Recommended absorb-wait (seconds) after this step: actives get 45s.
    private func waitSeconds(for item: RoutineItem) -> Int {
        if item.waitSeconds > 0 { return item.waitSeconds }
        guard let product = product(item) else { return 0 }
        return IngredientEngine.profile(for: product).actives.isEmpty ? 0 : 45
    }

    var body: some View {
        ZStack {
            GradientMeshBackground()
            if index >= items.count {
                completeView
            } else {
                stepView(items[index])
            }
        }
        .navigationTitle("timer.title")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { waitTask?.cancel() }
    }

    private func stepView(_ item: RoutineItem) -> some View {
        VStack(spacing: 18) {
            Text("timer.step \(index + 1) \(items.count)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Image(systemName: "drop.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.accent)
                .blueGlow()
            Text(verbatim: product(item)?.name ?? "—")
                .font(Typography.display(30))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("timer.apply.instruction")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            if waiting {
                VStack(spacing: 10) {
                    Text("timer.wait")
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    Text(verbatim: "\(waitRemaining)s")
                        .font(Typography.number(48, weight: .bold))
                        .foregroundStyle(Theme.primary)
                    SecondaryButton(titleKey: "timer.skip") { finishWait() }
                }
            } else {
                PrimaryButton(titleKey: "timer.applied", systemImage: "checkmark") {
                    advance(from: item)
                }
                .padding(.horizontal, 30)
            }
        }
        .padding(24)
    }

    private var completeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 54))
                .foregroundStyle(Theme.success)
                .blueGlow(Theme.success, radius: 22, opacity: 0.4)
            Text("timer.done.title")
                .font(Typography.display(28)).foregroundStyle(Theme.textPrimary)
            PrimaryButton(titleKey: "common.done") { dismiss() }
                .padding(.horizontal, 40).padding(.top, 6)
        }
        .padding(24)
    }

    private func advance(from item: RoutineItem) {
        let seconds = waitSeconds(for: item)
        if seconds > 0 {
            waiting = true
            waitRemaining = seconds
            waitTask = Task { @MainActor in
                while waitRemaining > 0 {
                    try? await Task.sleep(for: .seconds(1))
                    if Task.isCancelled { return }
                    waitRemaining -= 1
                }
                finishWait()
            }
        } else {
            next()
        }
    }

    private func finishWait() {
        waitTask?.cancel()
        waiting = false
        next()
    }

    private func next() {
        Haptics.fire(.milestone)
        index += 1
        if index >= items.count { Haptics.fire(.verdictReveal) }
    }
}
