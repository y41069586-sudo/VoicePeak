import SwiftUI
import SwiftData

/// "A routine you can prove." AM/PM plan built only from products that passed
/// their half-face test, with routine-conflict heads-ups and a step timer.
struct RoutineView: View {
    @Environment(AppState.self) private var appState
    @Query private var routineItems: [RoutineItem]
    @Query private var products: [Product]

    private var proven: [RoutineItem] { routineItems.filter(\.proven) }
    private func items(_ time: TimeOfDay) -> [RoutineItem] {
        proven.filter { $0.timeOfDay == time }.sorted { $0.order < $1.order }
    }
    private func product(_ item: RoutineItem) -> Product? {
        products.first { $0.id == item.productID }
    }

    private var conflicts: [ConflictWarning] {
        let profiles = proven.compactMap { product($0) }.map { IngredientEngine.profile(for: $0) }
        let signals = IngredientConflicts.routineSignals(routineProfiles: profiles, currentProducts: [])
        return IngredientConflicts.internalWarnings(signals: signals)
    }

    var body: some View {
        NavigationStack {
            Group {
                if proven.isEmpty {
                    emptyState
                } else {
                    routineList
                }
            }
            .navigationTitle("tab.routine")
            .toolbar {
                if !proven.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            RoutineTimerView(items: orderedForTimer)
                        } label: {
                            Label("routine.start", systemImage: "play.circle.fill")
                        }
                    }
                }
            }
        }
    }

    /// AM then PM, in order, for the step timer.
    private var orderedForTimer: [RoutineItem] {
        items(.am) + items(.pm)
    }

    private var routineList: some View {
        List {
            if !conflicts.isEmpty {
                Section("routine.conflicts") {
                    ForEach(conflicts) { conflict in
                        Label {
                            Text(conflict.titleKey).font(.footnote)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle").foregroundStyle(Theme.warning)
                        }
                    }
                }
            }
            ForEach(TimeOfDay.allCases) { time in
                let list = items(time)
                if !list.isEmpty {
                    Section(time.localizationKey) {
                        ForEach(list) { item in
                            routineRow(item)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(GradientMeshBackground())
    }

    private func routineRow(_ item: RoutineItem) -> some View {
        HStack(spacing: 12) {
            RemoteImage(urlString: product(item)?.imageURLString) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.bgElevated)
                    .overlay(Image(systemName: "drop.fill").font(.caption).foregroundStyle(Theme.accent))
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: product(item)?.name ?? "—")
                    .font(.subheadline).foregroundStyle(Theme.textPrimary)
                if let brand = product(item)?.brand, !brand.isEmpty {
                    Text(verbatim: brand).font(.caption).foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            PillTag(titleKey: "routine.proven", systemImage: "checkmark.seal.fill", tone: .success)
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checklist")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(Theme.accent)
            Text("routine.empty.title")
                .font(Typography.display(24)).foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("routine.empty.body")
                .font(.subheadline).foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)
            NavigationLink {
                CatalogView()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles.rectangle.stack")
                    Text("dashboard.action.analyzeProduct")
                }
                .font(VType.bodyLarge.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(VColor.heroGradient, in: Capsule())
                .vGlow(VColor.primary, radius: 22, opacity: 0.25)
            }
            .buttonStyle(PressableStyle(brightenOnPress: true))
            .padding(.horizontal, 34).padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GradientMeshBackground())
    }
}
