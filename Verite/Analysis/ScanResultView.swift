import SwiftUI
import UIKit

/// Replaced premium results view with 5-section cinematic reveal experience.
/// Presents skin health insights based on the analysis output using calm adjectives.
struct ScanResultView: View {
    let image: UIImage?
    let analysis: ScanAnalysis
    let isBaseline: Bool
    let captureQuality: Double
    let scans: [Scan]
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var snapshot: MockSkinSnapshot?
    @State private var animateIn = false

    private var isFollowUp: Bool {
        !isBaseline && BaselineTracker.fullScans(scans).count >= AnalysisConfidence.minScansForChange
    }

    private var reliable: Bool { BaselineTracker.hasReliableVerdict(scans) }

    var body: some View {
        ZStack {
            GradientMeshBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if let snapshot {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Section 1: Header + Score Orb
                            VStack(spacing: 16) {
                                if let image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 130)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .strokeBorder(VColor.strokeSubtle, lineWidth: 1)
                                        )
                                        .blueGlow(Theme.accent, radius: 15, opacity: 0.25)
                                }

                                HStack(spacing: 8) {
                                    Image(systemName: captureQuality >= 0.7 ? "checkmark.seal.fill" : "sparkles")
                                        .foregroundStyle(captureQuality >= 0.7 ? Theme.success : Theme.accent)
                                    Text(captureQuality >= 0.7 ? "Standardized Capture" : "Quick Scan")
                                        .font(VType.micro)
                                        .foregroundStyle(VColor.textSecondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial, in: Capsule())

                                SkinScoreOrb(score: snapshot.score)
                                    .scaleEffect(animateIn ? 1.0 : 0.9)
                                    .opacity(animateIn ? 1.0 : 0.0)

                                Text(snapshot.headline)
                                    .font(VType.heroTitle)
                                    .foregroundStyle(VColor.textPrimary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                            }
                            .padding(.top, 16)

                            // Section 2: Key Insight Sentence
                            GlassCard(featured: true) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Verite Insight")
                                        .vEyebrow()
                                    Text(snapshot.keyInsight)
                                        .font(VType.bodyMedium)
                                        .foregroundStyle(VColor.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .opacity(animateIn ? 1.0 : 0.0)

                            // Section 3: Attribute Grid
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(snapshot.attributes) { attr in
                                    SkinAttributeCard(display: attr)
                                }
                            }
                            .opacity(animateIn ? 1.0 : 0.0)

                            // Section 4: Heatmap Overlay
                            HeatmapOverlay(regions: snapshot.heatmapRegions)
                                .opacity(animateIn ? 1.0 : 0.0)

                            // Section 5: What Changed (for follow-ups)
                            if isFollowUp {
                                if reliable {
                                    WhatChangedCard(changes: BaselineTracker.changes(scans))
                                        .opacity(animateIn ? 1.0 : 0.0)
                                } else {
                                    GlassCard {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "hourglass")
                                                    .foregroundStyle(Theme.warning)
                                                Text("More Scans Needed").font(VType.title)
                                            }
                                            .foregroundStyle(VColor.textPrimary)
                                            Text("We need a few more scans to establish a highly reliable delta trend compared to your baseline.")
                                                .font(VType.body)
                                                .foregroundStyle(VColor.textSecondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                            } else if isBaseline {
                                GlassCard {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Baseline Established")
                                            .font(VType.title)
                                            .foregroundStyle(VColor.textPrimary)
                                        Text("This scan is saved as your Day 0 starting point. Future scans will highlight changes vs this capture.")
                                            .font(VType.body)
                                            .foregroundStyle(VColor.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }

                            // Section 6: Recommendations
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Recommendations")
                                    .font(VType.sectionTitle)
                                    .foregroundStyle(VColor.textPrimary)

                                ForEach(snapshot.recommendations) { rec in
                                    RecommendationCard(rec: rec) {
                                        // Simple placeholder action to add recommend steps
                                        Haptics.fire(.selection)
                                    }
                                }
                            }
                            .opacity(animateIn ? 1.0 : 0.0)

                            DisclaimerBanner(style: .short)
                        }
                        .padding(20)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    ProgressView("Analyzing scan detail...")
                        .tint(Theme.primary)
                }

                PrimaryButton(titleKey: "common.done", action: onDone)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .onAppear {
            generateSnapshot()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                animateIn = true
            }
        }
    }

    private func generateSnapshot() {
        snapshot = MockSkinSnapshot.generate(from: analysis)
    }
}
