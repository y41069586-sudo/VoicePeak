import SwiftUI

/// Primary Button (DESIGN_SPEC §6.2): `heroGradient` pill, 54pt tall, white
/// semibold label, primary glow when enabled, press = scale 0.97 + brightness.
/// Reserved for the single primary action on a screen.
struct PrimaryButton: View {
    let titleKey: LocalizedStringKey
    var systemImage: String? = nil
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.fire(.selection)
            action()
        } label: {
            HStack(spacing: VSpace.sm) {
                if let systemImage { Image(systemName: systemImage) }
                Text(titleKey)
            }
            .font(VType.bodyLarge.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(VColor.heroGradient, in: Capsule())
            .vGlow(VColor.primary, radius: 22, opacity: isEnabled ? 0.25 : 0)
            .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(PressableStyle(brightenOnPress: true))
        .disabled(!isEnabled)
    }
}

/// Secondary / Ghost Button (DESIGN_SPEC §6.3): frosted over elevated, bright
/// stroke, pill, no glow.
struct SecondaryButton: View {
    let titleKey: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(titleKey)
                .font(VType.bodyLarge.weight(.medium))
                .foregroundStyle(VColor.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(VColor.strokeBright, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }
}

/// Press feedback (DESIGN_SPEC §6.2): scale 0.97 (+ optional brightness) with the
/// press spring; collapses to a plain opacity change under Reduce Motion.
struct PressableStyle: ButtonStyle {
    var brightenOnPress: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
            .brightness(brightenOnPress && configuration.isPressed ? -0.05 : 0)
            .opacity(configuration.isPressed ? 0.96 : 1)
            .animation(VMotion.press, value: configuration.isPressed)
    }
}
