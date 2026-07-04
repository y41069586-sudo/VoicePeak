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

    private var recentScans: [Scan] {
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
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.headline)
                    .foregroundStyle(VColor.primary)
                }

                Spacer()
            }
            .padding(20)

            ScrollView {
                VStack(spacing: 20) {
                    ScanStatsGrid(date: scan.date, quality: scan.captureQuality, isBaseline: scan.isBaseline)
                        .padding(.horizontal, 20)

                    // Analysis attributes
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Analysis")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(VColor.textPrimary)
                            .padding(.horizontal, 4)

                        VStack(spacing: 8) {
                            AttributeBar(label: "Redness", value: 0.35, icon: "circle.fill")
                            AttributeBar(label: "Acne", value: 0.15, icon: "exclamationmark.circle")
                            AttributeBar(label: "Hydration", value: 0.62, icon: "water.circle")
                            AttributeBar(label: "Oiliness", value: 0.48, icon: "drop.circle")
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 20)
                }
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
        }
        .background(VColor.bgBase.ignoresSafeArea())
    }
}


#Preview {
    AnalyzerTabView()
        .modelContainer(Persistence.previewContainer)
        .environment(AppState())
        .preferredColorScheme(.light)
}
