import SwiftUI

// ============================================================
// MARK: — The device
// ============================================================

/// An iPhone, drawn in SwiftUI at true proportions: 402 × 874pt of display
/// inside a titanium rail, with the Dynamic Island, the four side buttons and
/// the home indicator where the hardware actually puts them.
///
/// The point of drawing it rather than shipping a PNG is what goes inside. The
/// screen takes a LIVE view, authored at full device size and scaled down as a
/// whole — so the mockups on the opening carousel are the app's own code, and
/// they cannot drift out of date the way a captured screenshot does the next
/// time a screen changes. Authoring at 402pt also means the type inside obeys
/// the same scale as the real screens; nothing has to be re-sized by eye.
struct RampPhoneFrame<Screen: View>: View {
    /// Outer width of the finished device, in points.
    var width: CGFloat = 208
    /// The diagonal glass reflection. Off for the phones set behind others,
    /// where a second highlight only muddies the stack.
    var glare: Bool = true
    @ViewBuilder var screen: () -> Screen

    /// iPhone 16 Pro: 402 × 874pt of display, 55pt display corner radius.
    static var displaySize: CGSize { CGSize(width: 402, height: 874) }

    private var bezel: CGFloat { width * 0.023 }
    private var screenWidth: CGFloat { width - bezel * 2 }
    private var screenHeight: CGFloat { screenWidth * Self.displaySize.height / Self.displaySize.width }
    private var height: CGFloat { screenHeight + bezel * 2 }
    private var screenRadius: CGFloat { screenWidth * 55 / Self.displaySize.width }
    private var outerRadius: CGFloat { screenRadius + bezel }
    private var scale: CGFloat { screenWidth / Self.displaySize.width }

    var body: some View {
        ZStack {
            sideButtons

            // The rail. A single dark body carries the bezel; the metal edge is
            // a gradient stroke on top of it.
            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                .fill(Color(hex: "1B1917"))
                .frame(width: width, height: height)

            display
                .overlay(alignment: .top) { dynamicIsland }
                .overlay(alignment: .bottom) { homeIndicator }
                .overlay { if glare { glassGlare } }
                .clipShape(RoundedRectangle(cornerRadius: screenRadius, style: .continuous))

            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                .strokeBorder(railMetal, lineWidth: max(1, width * 0.007))
                .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
        .shadow(color: RampStage.ink.opacity(0.30), radius: width * 0.14, y: width * 0.075)
        .accessibilityHidden(true)
    }

    /// The live screen, authored at device size and scaled as one piece.
    private var display: some View {
        screen()
            .frame(width: Self.displaySize.width, height: Self.displaySize.height)
            .scaleEffect(scale, anchor: .center)
            .frame(width: screenWidth, height: screenHeight)
            .clipped()
    }

    /// Brushed titanium: light at the top-left, dark through the middle,
    /// catching again at the bottom-right.
    private var railMetal: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "C9C2B8"), Color(hex: "6E665C"),
                     Color(hex: "3A352F"), Color(hex: "8E867B")],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var dynamicIsland: some View {
        Capsule()
            .fill(Color.black)
            .frame(width: screenWidth * 125 / Self.displaySize.width,
                   height: screenWidth * 37 / Self.displaySize.width)
            .overlay(alignment: .trailing) {
                // The front camera, just inside the right end.
                Circle()
                    .fill(Color(hex: "16181C"))
                    .frame(width: screenWidth * 15 / Self.displaySize.width)
                    .padding(.trailing, screenWidth * 6 / Self.displaySize.width)
            }
            .padding(.top, screenWidth * 11 / Self.displaySize.width)
    }

    private var homeIndicator: some View {
        Capsule()
            .fill(Color.black.opacity(0.28))
            .frame(width: screenWidth * 139 / Self.displaySize.width,
                   height: max(1.5, screenWidth * 5 / Self.displaySize.width))
            .padding(.bottom, screenWidth * 8 / Self.displaySize.width)
    }

    /// One soft diagonal band across the glass — enough to read as a screen
    /// under light, not so much that it washes the content out.
    private var glassGlare: some View {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(0.16), location: 0.00),
                .init(color: .white.opacity(0.05), location: 0.18),
                .init(color: .clear,               location: 0.42),
                .init(color: .white.opacity(0.07), location: 0.72),
                .init(color: .clear,               location: 0.86),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        .allowsHitTesting(false)
    }

    /// Action button and volume rocker on the left, power on the right — each
    /// a sliver of rail peeking out past the body.
    private var sideButtons: some View {
        let thickness = width * 0.014
        return ZStack {
            button(height: height * 0.038, y: -height * 0.212, leading: true, thickness: thickness)
            button(height: height * 0.068, y: -height * 0.118, leading: true, thickness: thickness)
            button(height: height * 0.068, y: -height * 0.030, leading: true, thickness: thickness)
            button(height: height * 0.104, y: -height * 0.086, leading: false, thickness: thickness)
        }
    }

    private func button(height buttonHeight: CGFloat, y: CGFloat,
                        leading: Bool, thickness: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: thickness / 2, style: .continuous)
            .fill(LinearGradient(colors: [Color(hex: "8E867B"), Color(hex: "4A443D")],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: thickness * 2, height: buttonHeight)
            .offset(x: (leading ? -1 : 1) * (width / 2 - thickness / 2), y: y)
    }
}

// ============================================================
// MARK: — The trio
// ============================================================

/// Three phones, the middle one forward. The pair behind are scaled down,
/// tipped a few degrees outward and pushed back with a wash of the ground
/// colour, so the eye reads depth and lands on the centre screen first.
struct RampPhoneTrio<Left: View, Center: View, Right: View>: View {
    /// Overall width of the composition.
    var width: CGFloat = 340
    @ViewBuilder var left: () -> Left
    @ViewBuilder var center: () -> Center
    @ViewBuilder var right: () -> Right

    private var centerWidth: CGFloat { width * 0.475 }
    private var sideWidth: CGFloat { centerWidth * 0.88 }

    var body: some View {
        ZStack {
            side(rotation: -5, offset: -centerWidth * 0.60) { left() }
            side(rotation: 5, offset: centerWidth * 0.60) { right() }

            RampPhoneFrame(width: centerWidth) { center() }
                .zIndex(1)
        }
        .frame(width: width, height: centerWidth * 874 / 402 * 1.10)
        .accessibilityHidden(true)
    }

    private func side<Content: View>(rotation: Double, offset: CGFloat,
                                     @ViewBuilder content: @escaping () -> Content) -> some View {
        RampPhoneFrame(width: sideWidth, glare: false, screen: content)
            .overlay(
                RoundedRectangle(cornerRadius: sideWidth * 0.16, style: .continuous)
                    .fill(RampStage.porcelain.opacity(0.22))
            )
            .rotationEffect(.degrees(rotation))
            .offset(x: offset, y: -centerWidth * 0.02)
    }
}

#Preview {
    ZStack {
        RampBackdrop()
        RampPhoneFrame(width: 240) {
            ZStack { RampStage.porcelain; Text(verbatim: "402 × 874").font(.system(size: 40)) }
        }
    }
}
