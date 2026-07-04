import SwiftUI

/// Premium hero section with animated scan ring and call-to-action.
/// The visual centerpiece of the Analyzer tab.
struct ScannerHeroSection: View {
    let action: () -> Void
    
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 20) {
            // Animated scan ring with glow
            ZStack {
                // Subtle outer circle
                Circle()
                    .stroke(VColor.strokeSubtle, lineWidth: 1)
                    .frame(width: 140, height: 140)
                
                // Animated gradient ring
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [VColor.primary, VColor.accent]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 140, height: 140)
                    .opacity(pulse ? 0.4 : 0.8)
                
                // Center icon
                Image(systemName: "camera.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(VColor.primary)
            }
            .padding(.top, 16)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            
            // Headline and description
            VStack(spacing: 8) {
                Text("Live Skin Analysis")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(VColor.textPrimary)
                
                Text("AI-powered scanning in real-time. Get instant insights into your skin's condition.")
                    .font(.callout)
                    .foregroundStyle(VColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            // CTA Button
            Button(action: action) {
                HStack(spacing: 10) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Start Scanning")
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
                .vGlow(VColor.primary, radius: 12, opacity: 0.2)
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(VColor.bgSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VColor.strokeSubtle, lineWidth: 1))
        .padding(.horizontal, 20)
    }
}

#Preview {
    ScannerHeroSection {
        print("Scan action")
    }
    .padding(.vertical, 20)
    .background(VColor.bgBase)
}
