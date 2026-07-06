import SwiftUI

/// Cinematic scanning overlay shown after capture. Full-screen visual intelligence effect
/// with mesh lattice, concentric rings, region-specific highlighting, and status cycles.
struct ScanningPhaseOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activeRegion: ScanningRegion = .forehead
    @State private var pulseOuter = false
    @State private var pulseInner = false
    @State private var statusText: String = "Mapping face geometry..."

    enum ScanningRegion: Int, CaseIterable {
        case forehead
        case nose
        case leftCheek
        case rightCheek
        case chin

        var label: String {
            switch self {
            case .forehead: return "Mapping face geometry..."
            case .nose: return "Measuring hydration barrier..."
            case .leftCheek: return "Reading texture variance..."
            case .rightCheek: return "Assessing lipid balance..."
            case .chin: return "Calibrating sensitivity levels..."
            }
        }

        func position(in size: CGSize) -> CGPoint {
            let cx = size.width / 2
            let cy = size.height * 0.44
            let ow = size.width * 0.70
            let oh = size.height * 0.46
            switch self {
            case .forehead: return CGPoint(x: cx, y: cy - oh * 0.28)
            case .nose: return CGPoint(x: cx, y: cy - oh * 0.05)
            case .leftCheek: return CGPoint(x: cx - ow * 0.22, y: cy + oh * 0.05)
            case .rightCheek: return CGPoint(x: cx + ow * 0.22, y: cy + oh * 0.05)
            case .chin: return CGPoint(x: cx, y: cy + oh * 0.28)
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Darkened backdrop spotlit around the alignment zone
                Color.black.opacity(0.65)
                    .ignoresSafeArea()

                // 1. Mesh dot lattice overlay
                MeshLatticeView()

                // 2. Concentric scanning rings centered on the face alignment oval
                let cx = geo.size.width / 2
                let cy = geo.size.height * 0.44
                let ow = geo.size.width * 0.70
                let oh = geo.size.height * 0.46

                Group {
                    // Inner ring
                    Ellipse()
                        .stroke(Theme.accent.opacity(0.4), lineWidth: 1.5)
                        .frame(width: ow * 0.6, height: oh * 0.6)
                        .scaleEffect(pulseInner ? 1.08 : 0.95)

                    // Middle ring
                    Ellipse()
                        .stroke(Theme.primary.opacity(0.3), lineWidth: 1.0)
                        .frame(width: ow * 0.85, height: oh * 0.85)

                    // Outer ring
                    Ellipse()
                        .stroke(Theme.primary.opacity(0.2), lineWidth: 1.0)
                        .frame(width: ow * 1.1, height: oh * 1.1)
                        .scaleEffect(pulseOuter ? 1.05 : 0.98)
                }
                .position(x: cx, y: cy)

                // 3. Spotlight highlight on the currently active region
                SpotlightHighlight()
                    .position(activeRegion.position(in: geo.size))
                    .id(activeRegion)

                // 4. Status UI at the bottom
                VStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Text(statusText)
                            .font(VType.bodyMedium)
                            .foregroundStyle(.white)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .id(statusText)

                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.9)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.bottom, 48)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            startAnimationCycle()
        }
    }

    private func startAnimationCycle() {
        if !reduceMotion {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseOuter = true
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseInner = true
            }
        }

        // Cycle regions and status labels sequentially
        Task {
            for region in ScanningRegion.allCases {
                activeRegion = region
                statusText = region.label
                Haptics.fire(.selection)
                try? await Task.sleep(for: .seconds(0.95))
            }
        }
    }
}

struct MeshLatticeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            let cols = 7
            let rows = 11
            let spacingX = geo.size.width / CGFloat(cols + 1)
            let spacingY = geo.size.height / CGFloat(rows + 1)

            ZStack {
                ForEach(0..<cols, id: \.self) { c in
                    ForEach(0..<rows, id: \.self) { r in
                        let x = spacingX * CGFloat(c + 1)
                        let y = spacingY * CGFloat(r + 1)
                        // Check if coordinate is within face alignment oval bounds
                        let dx = (x - geo.size.width / 2) / (geo.size.width * 0.38)
                        let dy = (y - geo.size.height * 0.44) / (geo.size.height * 0.25)
                        if dx*dx + dy*dy <= 1.0 {
                            Circle()
                                .fill(Theme.accent.opacity(0.18))
                                .frame(width: 3.5, height: 3.5)
                                .position(x: x, y: y)
                                .opacity(animate ? 1.0 : 0.2)
                                .animation(
                                    reduceMotion ? .default :
                                    .easeInOut(duration: 0.9)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(c + r) * 0.04),
                                    value: animate
                                )
                        }
                    }
                }
            }
            .onAppear {
                animate = true
            }
        }
    }
}

struct SpotlightHighlight: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 0.85
    @State private var opacity: Double = 0.35

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Theme.accent.opacity(0.35), Theme.primary.opacity(0.1), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 55
                )
            )
            .frame(width: 140, height: 140)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                if !reduceMotion {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                        scale = 1.15
                        opacity = 0.70
                    }
                }
            }
    }
}
