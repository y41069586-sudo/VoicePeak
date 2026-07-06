import SwiftUI
import SwiftData
import UIKit

/// §5.6 — the signature screen. Leads with the honest verdict (often "not for
/// you"), shows a risk/benefit heatmap on the user's real scan, checks routine
/// conflicts, and finds cheaper dupes that also fit. Ends with the real test CTA.
struct HonestMatchView: View {
    let product: Product

    @Environment(AppState.self) private var appState
    @Query private var scans: [Scan]
    @Query private var profiles: [UserProfile]
    @Query private var allProducts: [Product]
    @Query private var routineItems: [RoutineItem]

    @State private var showTestSetup = false

    private var userProfile: UserProfile? { profiles.first }
    private var productProfile: ProductProfile { IngredientEngine.profile(for: product) }

    var body: some View {
        ScrollView {
            if let context = SkinContext.build(scans: scans, profile: userProfile) {
                matchContent(context)
            } else {
                needScan
            }
        }
        .scrollIndicators(.hidden)
        .navigationTitle("match.title")
        .navigationBarTitleDisplayMode(.inline)
        .background(GradientMeshBackground())
        .sheet(isPresented: $showTestSetup) {
            HalfFaceTestSetupView(product: product)
        }
    }

    // MARK: Content

    @ViewBuilder
    private func matchContent(_ context: SkinContext) -> some View {
        let result = MatchEngine.evaluate(profile: productProfile, context: context)
        let conflicts = conflicts(context)
        let dupes = DupeFinder.find(for: product, in: allProducts, context: context)
        let thumbnail = (BaselineTracker.latest(scans) ?? BaselineTracker.baseline(scans))?
            .thumbnailFilename.flatMap { ThumbnailStore.load($0) }

        VStack(spacing: 16) {
            verdictHero(result)
            if let thumbnail { heatmapCard(thumbnail, result.zones) }
            reasonsCard(result)
            if !conflicts.isEmpty { conflictsCard(conflicts) }
            if !dupes.isEmpty { dupesCard(dupes) }
            testCTA
            DisclaimerBanner(style: .short)
        }
        .padding(20)
    }

    private func conflicts(_ context: SkinContext) -> [ConflictWarning] {
        let routineProfiles = routineItems
            .compactMap { item in allProducts.first { $0.id == item.productID } }
            .map { IngredientEngine.profile(for: $0) }
        let signals = IngredientConflicts.routineSignals(
            routineProfiles: routineProfiles,
            currentProducts: userProfile?.currentProducts ?? []
        )
        return IngredientConflicts.check(product: productProfile, routine: signals)
    }

    // MARK: Sections

    private func verdictHero(_ result: MatchResult) -> some View {
        GlassCard {
            VStack(spacing: 10) {
                Image(systemName: result.verdict.systemImage)
                    .font(.system(size: 40))
                    .foregroundStyle(result.verdict.color)
                    .blueGlow(result.verdict.color, radius: 20, opacity: 0.4)
                Text(result.verdict.headlineKey)
                    .font(Typography.display(26))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(verbatim: product.name)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func heatmapCard(_ image: UIImage, _ zones: [FaceRegion: ZoneLevel]) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("match.section.heatmap")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                ZoneHeatmapView(image: image, zones: zones)
                    .frame(maxWidth: 260)
                    .frame(maxWidth: .infinity)
                HeatmapLegend()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func reasonsCard(_ result: MatchResult) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("match.section.reasons")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                if result.reasons.isEmpty {
                    Text("match.reason.neutral")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    ForEach(result.reasons) { ReasonRow(reason: $0) }
                }
            }
        }
    }

    private func conflictsCard(_ conflicts: [ConflictWarning]) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("match.section.conflicts", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.warning)
                ForEach(conflicts) { conflict in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.circle").font(.caption).foregroundStyle(Theme.warning)
                        Text(conflict.titleKey).font(.footnote).foregroundStyle(Theme.textPrimary)
                    }
                }
            }
        }
    }

    private func dupesCard(_ dupes: [Dupe]) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("match.section.dupes")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                ForEach(dupes) { dupe in
                    NavigationLink {
                        ProductDetailView(product: dupe.product)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            ProductRow(product: dupe.product)
                            FlexWrap(spacing: 6, lineSpacing: 6) {
                                ForEach(dupe.sharedActives, id: \.self) { active in
                                    Text(verbatim: active.capitalized)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Theme.accent)
                                        .padding(.horizontal, 9).padding(.vertical, 4)
                                        .background(Theme.accent.opacity(0.12), in: Capsule())
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var testCTA: some View {
        PrimaryButton(titleKey: "match.cta.test", systemImage: "flask.fill") {
            showTestSetup = true
        }
    }

    // MARK: No-scan state

    private var needScan: some View {
        VStack(spacing: 16) {
            Image(systemName: "face.dashed")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(Theme.accent)
            Text("match.needScan.title")
                .font(Typography.display(24))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("match.needScan.body")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            PrimaryButton(titleKey: "dashboard.action.scanNow", systemImage: "camera.viewfinder") {
                appState.selectedTab = .analyze
            }
            .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(20)
    }
}

/// One reason row: risk/benefit icon + localized title + specifics as chips.
private struct ReasonRow: View {
    let reason: MatchReason

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: reason.kind == .risk ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(reason.kind == .risk ? Theme.danger : Theme.success)
            VStack(alignment: .leading, spacing: 6) {
                Text(reason.titleKey)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if !reason.chips.isEmpty {
                    FlexWrap(spacing: 6, lineSpacing: 6) {
                        ForEach(reason.chips) { MatchChipView(chip: $0) }
                    }
                }
            }
        }
    }
}

/// Renders a match chip (localized token or verbatim string).
private struct MatchChipView: View {
    let chip: MatchChip

    var body: some View {
        switch chip.content {
        case .localized(let key):
            PillTag(titleKey: key, tone: .neutral)
        case .verbatim(let text):
            Text(verbatim: text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Theme.textSecondary.opacity(0.12), in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.textSecondary.opacity(0.25), lineWidth: 1))
        }
    }
}
