import SwiftUI
import SwiftData

/// Opt-in, anonymized aggregate efficacy — "worked for X% of testers like you."
/// Numbers only, no photos, ≥ 5 samples (enforced server-side). Only reachable
/// when `communityEnabled`.
struct CommunityEfficacyView: View {
    @Environment(AppState.self) private var appState
    @Query private var profiles: [UserProfile]

    @State private var items: [CommunityEfficacy] = []
    @State private var loading = true

    var body: some View {
        Group {
            if loading {
                ProgressView()
            } else if items.isEmpty {
                ContentUnavailableView("community.empty", systemImage: "person.3")
            } else {
                List {
                    Section {
                        ForEach(items) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(verbatim: item.productKey)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                HStack {
                                    Text(item.worksPercent.formatted(.percent.precision(.fractionLength(0))))
                                        .font(Typography.number(15)).foregroundStyle(Theme.success)
                                    Text("community.worked").font(.caption).foregroundStyle(Theme.textSecondary)
                                    Spacer()
                                    Text("community.samples \(item.sampleSize)")
                                        .font(.caption2).foregroundStyle(Theme.textSecondary)
                                }
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(Theme.bgSurface.opacity(0.6))
                        }
                    } header: {
                        Text("community.intro")
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("community.title")
        .navigationBarTitleDisplayMode(.inline)
        .background(GradientMeshBackground())
        .task { await load() }
    }

    private func load() async {
        let skinType = profiles.first?.skinType?.rawValue
        items = (try? await appState.backend.fetchCommunityEfficacy(skinType: skinType)) ?? []
        loading = false
    }
}
