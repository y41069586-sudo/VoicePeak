import SwiftUI
import SwiftData

/// Analyzer tab: THE CORE of Vérité. Cinematic, premium, guided face scanning
/// with live analysis, heatmaps, confidence scoring, and trend comparison.
/// This is the emotional and functional center of the app.
struct AnalyzerTabView: View {
    @Environment(AppState.self) private var appState
    @Query private var scans: [Scan]
    @State private var showCamera = false
    @State private var selectedScan: Scan?

    var recentScans: [Scan] {
        scans.sorted { $0.date > $1.date }.prefix(5).map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero section: scanning prompt
                    ScannerHeroSection {
                        showCamera = true
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    
                    if !recentScans.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Recent Scans")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(VColor.textPrimary)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                ForEach(recentScans) { scan in
                                    ScanHistoryRow(scan: scan) {
                                        selectedScan = scan
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .transition(.opacity)
                    }
                    
                    // Scanner insights
                    ScannerInsightsSection()
                        .transition(.opacity)
                    
                    // Privacy badge
                    PrivacyBadge()
                        .padding(.horizontal, 20)
                        .transition(.opacity)
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
            .background(VColor.bgBase.ignoresSafeArea())
            .navigationTitle("Analyzer")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCamera) {
                CameraScannerView(isPresented: $showCamera)
            }
            .navigationDestination(item: $selectedScan) { scan in
                ScanDetailView(scan: scan)
            }
        }
    }
}

// MARK: - Scanner Hero Section

private struct ScannerHeroSection: View {
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Animated scan ring (premium visual)
            ZStack {
                Circle()
                    .stroke(VColor.strokeSubtle, lineWidth: 1)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [VColor.primary, VColor.accent]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 120, height: 120)
                    .opacity(0.6)
                
                Image(systemName: "camera.fill")
                    .font(.title)
                    .foregroundStyle(VColor.primary)
            }
            .padding(.top, 16)
            
            VStack(spacing: 8) {
                Text("Live Skin Analysis")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(VColor.textPrimary)
                
                Text("Get real-time insights into your skin's redness, acne, hydration, and texture.")
                    .font(.callout)
                    .foregroundStyle(VColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: "camera.viewfinder")
                    Text("Start Scan")
                        .font(.headline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.white)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [VColor.primary, VColor.accent]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(10)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(VColor.bgSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VColor.strokeSubtle, lineWidth: 1))
        .padding(.horizontal, 20)
    }
}

// MARK: - Scan History Row

private struct ScanHistoryRow: View {
    let scan: Scan
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(VColor.bgElevated)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "photo.fill")
                            .foregroundStyle(VColor.textTertiary)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(scan.date.formatted(date: .abbreviated, time: .short))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(VColor.textPrimary)
                    
                    Text("Quality: \(Int(scan.captureQuality * 100))%")
                        .font(.caption)
                        .foregroundStyle(VColor.textTertiary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(VColor.textTertiary)
                    .font(.caption.weight(.semibold))
            }
            .padding(12)
            .background(VColor.bgSurface)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(VColor.strokeSubtle, lineWidth: 1))
        }
    }
}

// MARK: - Scanner Insights Section

private struct ScannerInsightsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How Scanning Works")
                .font(.headline.weight(.semibold))
                .foregroundStyle(VColor.textPrimary)
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                InsightStep(
                    number: 1,
                    title: "Position Face",
                    description: "Follow the AR guide to center your face in good lighting."
                )
                
                InsightStep(
                    number: 2,
                    title: "Capture Analysis",
                    description: "We analyze redness, acne, oiliness, hydration, and texture."
                )
                
                InsightStep(
                    number: 3,
                    title: "Instant Results",
                    description: "View detailed heatmaps and compare to your baseline."
                )
                
                InsightStep(
                    number: 4,
                    title: "Track Progress",
                    description: "Over time, see proof of what's working for your skin."
                )
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct InsightStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(VColor.primary)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(VColor.textPrimary)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(VColor.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(12)
        .background(VColor.bgSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
}

// MARK: - Privacy Badge

private struct PrivacyBadge: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(VColor.success)
            
            VStack(alignment: .leading, spacing: 1) {
                Text("On-Device Analysis")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VColor.textPrimary)
                
                Text("Your face never leaves your phone")
                    .font(.caption2)
                    .foregroundStyle(VColor.textSecondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(VColor.success.opacity(0.05))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(VColor.success.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Camera Scanner View (Placeholder)

private struct CameraScannerView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                HStack {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundStyle(.white)
                    
                    Spacer()
                }
                .padding(20)
                
                Spacer()
                
                VStack(spacing: 16) {
                    Text("Camera Access Required")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    
                    Text("Position your face in the circle to begin analysis.")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                    
                    // Placeholder scan circle
                    Circle()
                        .stroke(VColor.primary, lineWidth: 2)
                        .frame(width: 180, height: 180)
                }
                
                Spacer()
                
                Button(action: {
                    isPresented = false
                }) {
                    Text("Take Scan")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                        .padding(.vertical, 14)
                        .background(VColor.primary)
                        .cornerRadius(10)
                }
                .padding(20)
            }
        }
    }
}

// MARK: - Scan Detail View

private struct ScanDetailView: View {
    let scan: Scan
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundStyle(VColor.primary)
                }
                
                Spacer()
            }
            .padding(20)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Scan info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scan Details")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(VColor.textPrimary)
                        
                        ScanMetric(label: "Date", value: scan.date.formatted(date: .abbreviated, time: .short))
                        ScanMetric(label: "Quality", value: "\(Int(scan.captureQuality * 100))%")
                        ScanMetric(label: "Baseline", value: scan.isBaseline ? "Yes" : "No")
                    }
                    .padding(16)
                    .background(VColor.bgSurface)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    
                    // Analysis attributes (placeholder)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Analysis")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(VColor.textPrimary)
                        
                        VStack(spacing: 8) {
                            AttributeBar(label: "Redness", value: 0.35)
                            AttributeBar(label: "Acne", value: 0.15)
                            AttributeBar(label: "Hydration", value: 0.62)
                            AttributeBar(label: "Oiliness", value: 0.48)
                        }
                    }
                    .padding(16)
                    .background(VColor.bgSurface)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 20)
                }
            }
        }
        .background(VColor.bgBase.ignoresSafeArea())
    }
}

private struct ScanMetric: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundStyle(VColor.textSecondary)
            Spacer()
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(VColor.textPrimary)
        }
    }
}

private struct AttributeBar: View {
    let label: String
    let value: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(VColor.textSecondary)
            
            ProgressView(value: value)
                .tint(VColor.primary)
        }
    }
}

#Preview {
    AnalyzerTabView()
        .modelContainer(Persistence.previewContainer)
        .environment(AppState())
        .preferredColorScheme(.light)
}
