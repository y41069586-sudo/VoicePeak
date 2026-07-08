import SwiftUI
import SwiftData

/// Vérité AI advisor flow: pick a goal (presets + your own words) → Claude
/// analyzes your skin summary against the product catalog → 3 honest, ranked
/// recommendations. Only numbers + text leave the device, never a photo.
struct GoalAdvisorView: View {
    @Environment(AppState.self) private var appState
    @Query private var scans: [Scan]
    @Query private var profiles: [UserProfile]
    @Query(sort: \Product.name) private var products: [Product]

    @State private var selectedGoals: Set<SkinGoal> = []
    @State private var freeText = ""
    @State private var phase: Phase = .selecting
    @State private var result: AdvisorResult?

    enum Phase: Equatable { case selecting, loading, results, failed, empty }

    private var skinContext: SkinContext? {
        SkinContext.build(scans: scans.filter { $0.side == .full }, profile: profiles.first)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                switch phase {
                case .selecting: selection
                case .loading:   loadingCard
                case .results:   resultsSection
                case .failed:    stateCard("advisor.error", systemImage: "wifi.exclamationmark", tone: .warning)
                case .empty:     EmptyView()
                }
                DisclaimerBanner(style: .short)
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("advisor.title")
        .navigationBarTitleDisplayMode(.inline)
        .background(GradientMeshBackground())
    }

    // MARK: Header

    private var header: some View {
        GlassCard(featured: true) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Theme.accent)
                    Text("advisor.title")
                        .font(Typography.display(22))
                        .foregroundStyle(Theme.textPrimary)
                }
                Text("advisor.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Selection

    private var selection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if skinContext == nil {
                stateCard("advisor.needScan", systemImage: "face.dashed", tone: .info)
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("advisor.goals.prompt")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    FlexWrap(spacing: 8, lineSpacing: 8) {
                        ForEach(SkinGoal.allCases) { goal in
                            goalChip(goal)
                        }
                    }
                    Divider().background(VColor.strokeSubtle)
                    TextField("advisor.freetext.placeholder", text: $freeText, axis: .vertical)
                        .lineLimit(1...3)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                }
            }

            PrimaryButton(titleKey: "advisor.analyze", systemImage: "sparkles",
                          isEnabled: skinContext != nil) {
                Task { await runAdvisor() }
            }
        }
    }

    private func goalChip(_ goal: SkinGoal) -> some View {
        let selected = selectedGoals.contains(goal)
        return Button {
            Haptics.fire(.selection)
            if selected { selectedGoals.remove(goal) } else { selectedGoals.insert(goal) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: goal.systemImage).font(.caption2)
                Text(goal.localizationKey).font(VType.captionBold)
            }
            .foregroundStyle(selected ? .white : Theme.textPrimary)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(
                selected ? AnyShapeStyle(VColor.heroGradient) : AnyShapeStyle(Theme.bgElevated),
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(VColor.strokeSubtle, lineWidth: selected ? 0 : 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Loading

    private var loadingCard: some View {
        GlassCard {
            VStack(spacing: 14) {
                ProgressView().scaleEffect(1.2)
                Text("advisor.processing")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }

    // MARK: Results

    @ViewBuilder
    private var resultsSection: some View {
        if let result {
            VStack(alignment: .leading, spacing: 16) {
                Text("advisor.results.title")
                    .font(VType.sectionTitle)
                    .foregroundStyle(VColor.textPrimary)

                ForEach(Array(result.recommendations.enumerated()), id: \.element.id) { index, rec in
                    recommendationCard(rec, rank: index + 1)
                }

                if !result.overallNote.isEmpty {
                    GlassCard {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "quote.opening").foregroundStyle(Theme.accent)
                            Text(verbatim: result.overallNote)
                                .font(.footnote)
                                .foregroundStyle(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Button {
                    phase = .selecting
                    result = nil
                } label: {
                    Text("advisor.again")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func recommendationCard(_ rec: AdvisorRecommendation, rank: Int) -> some View {
        let product = products.first { $0.id.uuidString == rec.productID }
        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle().fill(Theme.primary.opacity(0.12)).frame(width: 34, height: 34)
                        Text(verbatim: "\(rank)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.primary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: rec.productName)
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        if let product, !product.brand.isEmpty {
                            Text(verbatim: product.brand)
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    Spacer(minLength: 4)
                    VStack(spacing: 0) {
                        Text(verbatim: "\(rec.fitScore)")
                            .font(Typography.number(20))
                            .foregroundStyle(Theme.textPrimary)
                        Text("advisor.fit").font(VType.micro).foregroundStyle(Theme.textSecondary)
                    }
                }

                ScoreBar(labelKey: "advisor.fit", value: Double(rec.fitScore) / 100.0,
                         tone: rec.fitScore >= 66 ? .success : (rec.fitScore >= 40 ? .warning : .danger))

                labeled("advisor.why", rec.why, icon: "checkmark.circle.fill", tint: Theme.success)
                labeled("advisor.review", rec.honestReview, icon: "text.quote", tint: Theme.accent)
                if !rec.caution.trimmingCharacters(in: .whitespaces).isEmpty {
                    labeled("advisor.caution", rec.caution, icon: "exclamationmark.triangle.fill", tint: Theme.warning)
                }

                if let product {
                    NavigationLink {
                        ProductDetailView(product: product)
                    } label: {
                        HStack(spacing: 6) {
                            Text("advisor.viewProduct")
                            Image(systemName: "chevron.right").font(.caption2.weight(.bold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func labeled(_ key: LocalizedStringKey, _ text: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(key, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Text(verbatim: text)
                .font(.footnote)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func stateCard(_ key: LocalizedStringKey, systemImage: String, tone: PillTag.Tone) -> some View {
        GlassCard {
            HStack(spacing: 10) {
                Image(systemName: systemImage).foregroundStyle(Theme.accent)
                Text(key).font(.subheadline).foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Run

    private func runAdvisor() async {
        guard let context = skinContext else { phase = .empty; return }
        phase = .loading
        let request = AdvisorRequest(
            skinSummary: Self.summarize(context),
            goalLabels: selectedGoals.map(\.promptLabel),
            freeText: freeText,
            candidates: candidates()
        )
        do {
            result = try await appState.advisor.recommend(request)
            phase = .results
            Haptics.fire(.verdictReveal)
        } catch {
            phase = .failed
            Haptics.fire(.riskFlagged)
        }
    }

    private func candidates() -> [AdvisorCandidate] {
        products.prefix(30).map { product in
            let profile = IngredientEngine.profile(for: product)
            return AdvisorCandidate(
                id: product.id.uuidString,
                name: product.name,
                brand: product.brand,
                actives: profile.actives.map(\.name),
                riskFlags: profile.riskFlags.map { $0.rawValue },
                comedogenicMax: profile.comedogenicMax
            )
        }
    }

    /// English text summary of the user's skin for the model — numbers only,
    /// no image.
    static func summarize(_ c: SkinContext) -> String {
        var parts: [String] = []
        if let type = c.skinType { parts.append("skin type: \(type.rawValue)") }
        if !c.concerns.isEmpty {
            parts.append("declared concerns: " + c.concerns.map(\.rawValue).sorted().joined(separator: ", "))
        }
        let metrics = SkinAttribute.allCases.compactMap { attr -> String? in
            let v = c.attribute(attr)
            guard v > 0 else { return nil }
            return "\(attr.rawValue) \(Int((v * 100).rounded()))/100"
        }
        if !metrics.isEmpty { parts.append("latest scan estimates (0-100, higher = more of that trait): " + metrics.joined(separator: ", ")) }
        if !c.sensitivities.isEmpty {
            parts.append("known sensitivities: " + c.sensitivities.joined(separator: ", "))
        }
        return parts.isEmpty ? "no scan data yet" : parts.joined(separator: "; ")
    }
}
