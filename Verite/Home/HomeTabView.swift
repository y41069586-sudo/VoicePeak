import SwiftUI
import SwiftData

/// Home tab: calm intelligent dashboard showing skin overview, today's insight,
/// active concerns, and recommended actions. Emotionally safe and visually clear.
struct HomeTabView: View {
    @Environment(AppState.self) private var appState
    @Query private var scans: [Scan]
    @Query private var tests: [HalfFaceTest]
    @Query private var streaks: [Streak]
    
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Skin health overview
                    SkinHealthCard(scans: scans)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    
                    // Active concerns
                    if !scans.isEmpty {
                        ActiveConcernsCard(scans: scans)
                            .transition(.opacity)
                    }
                    
                    // Today's recommendation
                    TodaysRecommendationCard()
                        .transition(.opacity)
                    
                    // Scan shortcut (primary action)
                    PrimaryActionCard {
                        appState.selectedTab = .analyzer
                    }
                    .transition(.opacity)
                    
                    // Hydration trend
                    HydrationTrendCard(scans: scans)
                        .transition(.opacity)
                    
                    // Consistency badge
                    if let streak = streaks.first {
                        ConsistencyCard(streak: streak)
                            .transition(.opacity)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(VColor.bgBase.ignoresSafeArea())
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(VColor.primary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsModalView(isPresented: $showSettings)
            }
        }
    }
}

// MARK: - Skin Health Card

private struct SkinHealthCard: View {
    let scans: [Scan]
    
    var hasBaseline: Bool {
        scans.contains(where: { $0.isBaseline })
    }
    
    var body: some View {
        if !hasBaseline {
            VStack(alignment: .leading, spacing: 12) {
                Text("Let's establish your baseline")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(VColor.textPrimary)
                
                Text("Your first scan helps us track real improvements over time.")
                    .font(.callout)
                    .foregroundStyle(VColor.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(VColor.bgSurface)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(VColor.strokeSubtle, lineWidth: 1))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Skin Status")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VColor.textSecondary)
                
                Text("Stable")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(VColor.textPrimary)
                
                ProgressView(value: 0.8)
                    .tint(VColor.success)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(VColor.bgSurface)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(VColor.strokeSubtle, lineWidth: 1))
        }
    }
}

// MARK: - Active Concerns Card

private struct ActiveConcernsCard: View {
    let scans: [Scan]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Concerns")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VColor.textSecondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Slight dryness detected", systemImage: "water.circle")
                    .font(.callout)
                    .foregroundStyle(VColor.textPrimary)
                
                Label("Normal oil levels", systemImage: "drop.circle.fill")
                    .font(.callout)
                    .foregroundStyle(VColor.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(VColor.bgSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
}

// MARK: - Today's Recommendation Card

private struct TodaysRecommendationCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(VColor.primary)
                Text("Today's Insight")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VColor.textSecondary)
            }
            
            Text("Focus on hydration today — apply your moisturizer while skin is still damp for better absorption.")
                .font(.callout)
                .foregroundStyle(VColor.textPrimary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    VColor.primary.opacity(0.05),
                    VColor.accent.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
}

// MARK: - Primary Action Card (Scan)

private struct PrimaryActionCard: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.title3.weight(.semibold))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan Your Skin")
                        .font(.headline.weight(.semibold))
                    Text("Live analysis")
                        .font(.caption)
                        .opacity(0.7)
                }
                
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.white)
            .padding(16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [VColor.primary, VColor.accent]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
        }
    }
}

// MARK: - Hydration Trend Card

private struct HydrationTrendCard: View {
    let scans: [Scan]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hydration Trend")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VColor.textSecondary)
            
            HStack(spacing: 16) {
                ForEach(0..<5, id: \.self) { index in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(VColor.primary.opacity(Double(index + 1) / 6))
                            .frame(height: CGFloat(20 + index * 8))
                        
                        Text("D\(index + 1)")
                            .font(.caption2)
                            .foregroundStyle(VColor.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(VColor.bgSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
}

// MARK: - Consistency Card

private struct ConsistencyCard: View {
    let streak: Streak
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Consistency Streak")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VColor.textSecondary)
                
                Text("\(streak.current) days")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(VColor.warning)
            }
            
            Spacer()
            
            Image(systemName: "flame.fill")
                .font(.title)
                .foregroundStyle(VColor.warning)
        }
        .padding(16)
        .background(VColor.bgSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
}

// MARK: - Settings Modal

private struct SettingsModalView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    NavigationLink("Profile", destination: Text("Profile Settings"))
                    NavigationLink("Privacy", destination: Text("Privacy Settings"))
                }
                
                Section("Preferences") {
                    NavigationLink("Notifications", destination: Text("Notification Settings"))
                    NavigationLink("Appearance", destination: Text("Appearance Settings"))
                }
                
                Section("Legal") {
                    NavigationLink("Terms of Service", destination: Text("Terms"))
                    NavigationLink("Privacy Policy", destination: Text("Privacy Policy"))
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    HomeTabView()
        .modelContainer(Persistence.previewContainer)
        .environment(AppState())
        .preferredColorScheme(.light)
}
