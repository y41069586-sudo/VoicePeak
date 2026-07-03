import SwiftUI

/// The signature primary CTA: gradient-filled capsule with a soft glow and a
/// haptic tick. Honors Reduce Motion (no scale bounce) and Dynamic Type.
struct PrimaryButton: View {
    let titleKey: LocalizedStringKey
    var systemImage: String? = nil
    var isEnabled: Bool = true
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            Haptics.fire(.selection)
            action()
        } label: {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(titleKey)
            }
            .font(.headline)
            .foregroundStyle(.white) // on the blue gradient capsule
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.signature, in: Capsule())
            .blueGlow(Theme.primary, radius: 22, opacity: isEnabled ? 0.45 : 0)
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(PressableStyle(reduceMotion: reduceMotion))
        .disabled(!isEnabled)
    }
}

/// A secondary, quieter button for skip / dismiss paths.
struct SecondaryButton: View {
    let titleKey: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(titleKey)
                .font(.headline)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

/// Subtle press feedback that collapses to a plain opacity change under Reduce Motion.
struct PressableStyle: ButtonStyle {
    var reduceMotion: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(Motion.springSnappy, value: configuration.isPressed)
    }
}
