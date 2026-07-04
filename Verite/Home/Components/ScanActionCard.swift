import SwiftUI

/// Primary hero action card prompting user to scan their skin.
/// Elegant gradient button with clear CTA.
struct ScanActionCard: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Text("Ready to scan?")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                        
                        Text("Get instant skin insights")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Image(systemName: "camera.viewfinder")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                }
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
        .contentShape(Rectangle())
    }
}

#Preview {
    ScanActionCard {
        print("Scan tapped")
    }
    .padding(20)
    .background(VColor.bgBase)
}
