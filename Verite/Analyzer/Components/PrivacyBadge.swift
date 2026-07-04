import SwiftUI

/// Privacy assurance badge showing on-device processing commitment.
struct PrivacyBadge: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(VColor.success)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Privacy First")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(VColor.textPrimary)
                
                Text("All analysis happens on your phone. Your face never leaves.")
                    .font(.caption)
                    .foregroundStyle(VColor.textSecondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    VColor.success.opacity(0.08),
                    VColor.success.opacity(0.04)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(VColor.success.opacity(0.2), lineWidth: 1))
    }
}

#Preview {
    PrivacyBadge()
        .padding(20)
        .background(VColor.bgBase)
}
