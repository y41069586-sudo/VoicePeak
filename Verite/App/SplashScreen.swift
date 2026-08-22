import SwiftUI

// ============================================================
// MARK: — Splash
// ============================================================

/// The first thing the app draws, and the only screen whose job is to get out
/// of the way.
///
/// HOW THE HANDOFF WORKS. A cold launch shows three things in a row, and the
/// user has to read them as one:
///
///   1. `LaunchScreen.storyboard` — flat white ground, the mark centred at
///      116pt.
///      iOS puts this up before our process is ready; it cannot animate.
///   2. This view — starts as an exact copy of that frame, then the halo
///      breathes out, the mark takes one breath, and the wordmark rises in
///      underneath.
///   3. The app, revealed as this lifts and dissolves away.
///
/// Step 1 and step 2's FIRST FRAME are the same picture on purpose, and that
/// is the constraint everything here is written around:
///
///  · The mark sits at the view's true centre, not centred as a stack with
///    the wordmark — a stack would place it half a wordmark higher and it
///    would jump the instant SwiftUI took over.
///  · The mark's scale starts at exactly 1, not at 0.96 springing up. A
///    "settle in" that starts smaller than the frame already on screen is a
///    jump with a nicer name.
///  · Mark size and ground colour are duplicated in the storyboard. Change
///    one without the other and every cold launch shows a jolt on the first
///    screen of the app, which is the worst place in the product to have one.
///
/// WHY IT HOLDS AT ALL. A splash that waits on nothing costs the user time,
/// so this one is under a second before it starts leaving. It is not a
/// loading screen and must never quietly become one: the model container and
/// the store are already up by the time it appears, and anything slow added
/// at launch later belongs behind its own state, not behind a longer hold.
struct SplashScreen: View {
    /// Called once the fade-out has finished and the view can be removed.
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 1 = exactly the storyboard frame. The breath goes UP from here and
    /// comes back; it never starts below it. See the note above.
    @State private var markScale: CGFloat = 1
    /// The halo behind the mark. Driven as a scale rather than by animating
    /// the gradient's `endRadius`, which SwiftUI cannot interpolate — that
    /// version snapped to its final size on the first frame.
    @State private var haloScale: CGFloat = 0.72
    @State private var haloIn = false
    /// The wordmark, rising in under the mark.
    @State private var wordmarkIn = false
    /// Exit, beat one: the mark, wordmark and halo lift and dissolve.
    @State private var contentGone = false
    /// Exit, beat two: the white ground follows, revealing the app.
    @State private var groundGone = false

    /// Duplicated in `LaunchScreen.storyboard` — keep them in step. There is
    /// no corner radius to match: `SplashMark` carries its squircle as alpha,
    /// so both frames draw the same pixels. See the storyboard's header.
    private let markSize: CGFloat = 116

    var body: some View {
        ZStack {
            // Beat two — see `leave`. Held at full opacity while the mark
            // leaves, so the mark always dissolves against white and never
            // against the app's own content.
            RampStage.porcelain
                .ignoresSafeArea()
                .opacity(groundGone ? 0 : 1)

            // Beat one: the composition lifts and dissolves as one, so the
            // app underneath reads as arriving rather than as the splash
            // being switched off.
            ZStack {
                halo
                mark
                    .overlay(alignment: .top) {
                        wordmark
                            .fixedSize()
                            .offset(y: markSize + 22)
                    }
            }
            .opacity(contentGone ? 0 : 1)
            .scaleEffect(contentGone ? 1.05 : 1)
            .offset(y: contentGone ? -14 : 0)
        }
        .task { await run() }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: Brand.name))
    }

    // MARK: Pieces

    /// A soft peach pool behind the mark — the one thing that moves during
    /// the hold, and deliberately almost too subtle. A visible pulse on a
    /// screen this short reads as a glitch rather than as warmth.
    private var halo: some View {
        RadialGradient(colors: [RampStage.accent.opacity(0.55),
                                RampStage.accent.opacity(0.14),
                                .clear],
                       center: .center, startRadius: 0, endRadius: 280)
            .frame(width: 560, height: 560)
            .scaleEffect(haloScale)
            .opacity(haloIn ? 1 : 0)
            .allowsHitTesting(false)
    }

    private var mark: some View {
        Image("SplashMark")
            .resizable()
            .scaledToFit()
            .frame(width: markSize, height: markSize)
            .shadow(color: RampStage.accentDeep.opacity(0.18), radius: 24, y: 10)
            .scaleEffect(markScale)
    }

    private var wordmark: some View {
        // `verbatim` — the brand name is a proper noun and is never localized.
        Text(verbatim: Brand.name)
            .font(.system(size: 32, weight: .heavy, design: .rounded))
            .foregroundStyle(RampStage.ink)
            .opacity(wordmarkIn ? 1 : 0)
            .offset(y: wordmarkIn ? 0 : 10)
    }

    // MARK: Sequence

    private func run() async {
        if reduceMotion {
            await runReduced()
            return
        }

        withAnimation(.easeOut(duration: 1.0)) {
            haloScale = 1
            haloIn = true
        }
        // One breath: up, then back to the size it started at.
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { markScale = 1.05 }
        try? await Task.sleep(for: .milliseconds(260))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) { markScale = 1 }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { wordmarkIn = true }

        // The hold — long enough for the wordmark to land and be read, short
        // enough that nobody waits on it.
        try? await Task.sleep(for: .milliseconds(560))
        guard !Task.isCancelled else { return }
        await leave(duration: 0.42)
    }

    /// Reduce Motion: nothing moves, but it is not instant either. Cutting
    /// straight to the app would flash the storyboard frame for a tick and
    /// snap it away, which is more jarring than a brief still hold.
    private func runReduced() async {
        haloScale = 1
        haloIn = true
        wordmarkIn = true
        try? await Task.sleep(for: .milliseconds(650))
        guard !Task.isCancelled else { return }
        await leave(duration: 0.28)
    }

    /// Fades out in two beats and hands back.
    ///
    /// The mark, wordmark and halo go first; the white ground follows only
    /// once they are ENTIRELY gone. Fading all of it together — which is
    /// what this did originally — meant the ground thinned at the same rate
    /// as the mark, so a ghosted "SkinFix" sat on top of the app's own
    /// headline. An earlier fix staggered the two fades but still started
    /// the ground's fade before the content's had finished (a ~60ms
    /// overlap) — enough for the ghost to still show. The wait below now
    /// matches the content fade's own duration exactly, so there is no
    /// window where both are translucent at once: the mark always leaves
    /// against fully opaque white, and the app is revealed by the ground
    /// alone.
    ///
    /// The final sleep matches the ground's own fade so the view is removed
    /// exactly as it finishes rather than a frame either side.
    private func leave(duration: Double) async {
        let contentFade = duration * 0.6
        withAnimation(.easeIn(duration: contentFade)) { contentGone = true }
        try? await Task.sleep(for: .seconds(contentFade))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: duration)) { groundGone = true }
        try? await Task.sleep(for: .seconds(duration))
        onFinished()
    }
}

#Preview {
    SplashScreen { }
}
