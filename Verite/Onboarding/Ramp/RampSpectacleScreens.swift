import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// ============================================================
// MARK: — Screen 0: Opening
// ============================================================

/// The opening carousel. Four product-led pages: the app itself running inside
/// a drawn iPhone, an acne-first headline, one line of substance. Horizontal
/// paging with dots, and — the part that matters for conversion — the SAME
/// primary CTA on every page, so nobody has to swipe four times to begin.
///
/// Two deliberate choices here:
///
/// 1. The art slot renders live screens (see `RampIntroArt`), not screenshots.
///    Showing the product outsells illustrating it — the page stops describing
///    the app and starts showing what you get — and building it from the app's
///    own views means there is no capture step to redo, and no chance of the
///    first screen a user ever sees showing last quarter's palette.
///
/// 2. "Already have an account?" sits on page one. Sign-in used to be step 18
///    of 21, and `onboardingComplete` lives only in the local store — so a
///    subscriber who reinstalled had to walk the entire funnel before they
///    could reach the button that restores what they already paid for.
struct RampBootScreen: View {
    let onAdvance: () -> Void
    /// Jump straight to sign-in. Returning users are not prospects; making
    /// them re-run the pitch is how you lose the ones you already won.
    var onSignIn: () -> Void = {}

    @State private var page = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Stays `false` until this view has been through one real SwiftUI
    /// layout pass. `TabView(.page)` is bridged to a `UIPageViewController`
    /// underneath, and on its very first pass it has been observed to hand
    /// its pages a stale width — the CTA loses its gutters and runs edge to
    /// edge, and the centred copy overflows both sides — before correcting
    /// itself a frame later. Pinning each page to `GeometryReader`'s
    /// measured width (below) narrows that window but does not close it,
    /// because the reader's own first read can race the same bridge. Hiding
    /// the screen until `.onAppear` has had a runloop turn to let that
    /// settle closes it outright — and costs nothing, since this view is
    /// built and mounted while `SplashScreen` still fully covers it.
    @State private var laidOut = false

    private struct IntroPage: Identifiable {
        let id: Int
        let title: String
        let sub: String
    }

    /// Acne first, in the app's own voice. No percentage claims and no
    /// "clear in N days" promise — the product measures and plans, it does
    /// not guarantee an outcome, and the copy stays inside what it can do.
    private let pages: [IntroPage] = [
        IntroPage(id: 0,
                  title: "The honest way\nto clear your skin.",
                  sub: "One scan, one real score from 0 to 100 — no filter, no sugarcoating."),
        IntroPage(id: 1,
                  title: "See what's driving\nyour breakouts.",
                  sub: "Seven metrics read from a single photo of your face — blemishes first."),
        IntroPage(id: 2,
                  title: "A routine built\naround your skin.",
                  sub: "Morning and evening, matched to your concerns and the ingredients you react to."),
        IntroPage(id: 3,
                  title: "Watch it change\nover 14 days.",
                  sub: "Every scan updates the plan and shows you what actually moved."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Every page is pinned to the MEASURED viewport width. Without
            // that, `TabView`'s first layout pass can hand its pages a width
            // that isn't the screen's, and everything inside lays out to that
            // instead: the CTA loses its 24pt gutters and runs edge to edge
            // with square corners, and the centred standfirst overflows off
            // both sides. A later pass corrects it, which is precisely why it
            // only ever showed as a flash — this screen is built while
            // `SplashScreen` still covers it, so the bad pass happens behind
            // the splash and the correction happens in full view, right as
            // the splash dissolves. Pinning the width means there is no bad
            // pass to correct.
            GeometryReader { proxy in
                TabView(selection: $page) {
                    ForEach(pages) { item in
                        introPage(item)
                            .frame(width: proxy.size.width)
                            .tag(item.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .frame(maxHeight: .infinity)

            dots
                .padding(.top, VSpace.sm)

            RampPrimaryButton(title: "Get started") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
                .padding(.top, VSpace.md)

            Button {
                Haptics.fire(.selection)
                onSignIn()
            } label: {
                Text("Already have an account?")
                    .font(VType.body)
                    .foregroundStyle(RampStage.textSecondary)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .padding(.top, VSpace.xs)
        }
        .padding(.bottom, VSpace.lg)
        .opacity(laidOut ? 1 : 0)
        .animation(VMotion.snappy, value: page)
        .task { await autoAdvance() }
        .onAppear {
            DispatchQueue.main.async { laidOut = true }
        }
    }

    /// Plays the carousel by itself — a beat to look at each page, then a
    /// snappy swipe to the next, wrapping back to the first. A user swipe
    /// still works at any time; it just sets the same `page` this loop
    /// drives. Off entirely under Reduce Motion, where an unrequested
    /// slideshow is exactly the kind of movement that setting exists to stop.
    private func autoAdvance() async {
        guard !reduceMotion else { return }

        // This screen is already mounted, and this `.task` already running,
        // while `SplashScreen` still covers it — `RootView` builds the whole
        // flow behind the splash on purpose, so it can dissolve straight
        // onto a finished layout instead of a blank one. The cost is that a
        // timer started here is running before the user can see anything.
        // The splash's own sequence lands at ~1.2s; a page flip landing in
        // that same moment reads as the reveal glitching rather than as a
        // clean handoff. The FIRST wait is longer than the loop's own
        // interval for exactly that reason — enough room that the two can
        // never land together, on a slow cold-launch device or a fast one.
        try? await Task.sleep(for: .seconds(3.4))
        while !Task.isCancelled {
            withAnimation(VMotion.snappy) {
                page = (page + 1) % pages.count
            }
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
        }
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(pages) { item in
                Capsule()
                    .fill(item.id == page ? RampStage.accentEdge : RampStage.hair)
                    .frame(width: item.id == page ? 18 : 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }

    private func introPage(_ item: IntroPage) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: VSpace.sm)

            RampIntroArt(index: item.id)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, VSpace.sm)

            Spacer(minLength: VSpace.md)

            VStack(spacing: VSpace.sm) {
                Text(LocalizedStringKey(item.title))
                    .font(RampStage.serif(30))
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(LocalizedStringKey(item.sub))
                    .font(VType.bodyLarge)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, VSpace.lg)
            }
            .padding(.horizontal, VSpace.md)

            Spacer(minLength: VSpace.md)
        }
        .frame(maxWidth: .infinity)
    }
}

/// The intro's visual slot: real iPhones, drawn, with the app's own screens
/// running live inside them.
///
/// This replaced three pieces of line-art — a mirror, a smiling circle and a
/// calendar. They were honest about being drawings, which was the problem: the
/// first four screens a new user sees were illustrations OF the product rather
/// than the product. What is here now is the actual code — `RampIntroReadingScreen`
/// and friends, laid out at the iPhone's true 402 × 874pt and scaled into a
/// drawn device — so the carousel shows what you get, and it cannot go stale
/// the way the screenshots this slot used to wait on would have.
private struct RampIntroArt: View {
    let index: Int

    var body: some View {
        // Sized up twice from the original 340×372 slot, which was small
        // enough on a real phone that the screens inside were decoration
        // rather than something you could read. The design size is now wider
        // than any iPhone's content width on purpose: `RampFitted` scales the
        // whole composition down to whatever room the page actually has, so
        // asking for more here buys detail on a big screen and costs nothing
        // on a small one — it just stops the mockups being needlessly tiny on
        // the devices that had the space all along.
        // Only page two shows a screen alone — the reading, because it's the
        // one page that needs one: "seven metrics" only reads as seven
        // metrics at a size where you can count them. Pages one, three and
        // four each put the screen their own headline is about in the
        // trio's centre instead (scan, routine, progress in turn) and fill
        // the other two slots with the rest of the app, so every page both
        // answers its own headline and keeps the whole product in view.
        RampFitted(designSize: CGSize(width: 420, height: 470)) {
            switch index {
            case 0:
                // The overview trio, the scan in the middle — page one's
                // line is "One scan, one real score", and the scan is the
                // "one scan" half of that sentence, so it leads, flanked by
                // the reading (the "one real score" half) and the rest of
                // the app.
                RampPhoneTrio(width: 412) {
                    RampIntroReadingScreen()
                } center: {
                    RampIntroScanScreen()
                } right: {
                    RampIntroRoutineScreen()
                }
            case 1:
                // The reading, alone and at full size — page two's line is
                // "Seven metrics read from a single photo", and the reading
                // is where all seven actually live (Blemishes, Redness,
                // Texture, Pores, Evenness, Hydration, Glow). Cramped into a
                // third of a trio, none of those seven are legible; alone,
                // every one of them is.
                RampPhoneFrame(width: 214) { RampIntroReadingScreen() }
            case 2:
                RampPhoneTrio(width: 412) {
                    RampIntroReadingScreen()
                } center: {
                    RampIntroRoutineScreen()
                } right: {
                    RampIntroProgressScreen()
                }
            default:
                RampPhoneTrio(width: 412) {
                    RampIntroRoutineScreen()
                } center: {
                    RampIntroProgressScreen()
                } right: {
                    RampIntroReadingScreen()
                }
            }
        }
        .frame(maxHeight: 470)
        .accessibilityHidden(true)
    }
}

/// Draws its content at a fixed design size, scaled down to whatever room the
/// page actually has. The mockups are laid out in absolute points, so without
/// this they would overrun the art slot on a small phone.
///
/// A non-positive proxy is treated as "not measured yet" and draws nothing,
/// rather than being divided by. `min` already yields 0 for a zero size, but a
/// NEGATIVE proposal — which SwiftUI can hand out mid-transition — produces a
/// negative scale, and that renders the whole composition mirrored.
///
/// NOT clipped, deliberately. Clipping to the slot would also be a way to stop
/// a stale proxy painting outside it, but the phone mockups carry shadows
/// (`RampPhoneFrame` uses `radius: width * 0.14`) and the trio is 412pt inside
/// a 420pt design box — so a tight clip cuts the shadows off square at the
/// slot edge on every frame, to guard against one that may not happen.
private struct RampFitted<Content: View>: View {
    let designSize: CGSize
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            let usable = proxy.size.width > 0 && proxy.size.height > 0
            let scale = usable
                ? min(proxy.size.width / designSize.width,
                      proxy.size.height / designSize.height, 1)
                : 0
            content()
                .frame(width: designSize.width, height: designSize.height)
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}


// ============================================================
// MARK: — Screen 1: A Reading (the real results chart, previewed)
// ============================================================

/// The strongest opener: the exact chart the app produces after a scan — a
/// circular photo above the reading, the numbers counting up from zero and
/// resolving from a blur, just like the real reveal. Illustrative data and a
/// stock example face; the user's own is built from their scan.
///
/// ONE NUMBER LEADS. This used to be six equal cells in a two-column grid,
/// which flattened the one figure the whole product is built on — the 0–100
/// score — into a peer of "Evenness". A reader scanning it came away with six
/// numbers in the sixties and no idea which one mattered. Overall now runs at
/// 72pt with the five sub-scores as compact rows beneath it, so the hierarchy
/// on the page matches the hierarchy in the product.
///
/// TWO LAYOUT FAULTS FIXED HERE, both of which only showed on a short canvas:
///
///  · The headline had no `fixedSize`, while the standfirst under it did. On a
///    viewport too short for the fixed VStack, SwiftUI compressed whichever
///    text would yield — so "Your skin, fully read." truncated to "Your
///    skin,…" with the standfirst below it intact and fully wrapped.
///  · There was no `ScrollView` at all, so a short canvas had nowhere to put
///    the overflow and every child got squeezed instead. It now scrolls with
///    `minHeight`, the same shape every other screen in the flow uses.
///
/// The standfirst is gone rather than fixed. It said "the exact chart your
/// first scan builds — photo and all", which is the picture explaining itself
/// while the picture is right there; the honesty line at the foot is the only
/// caption this screen actually needs.
struct RampSampleReadingScreen: View {
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reveal: Double = 0        // 0 → 1 count-up driver

    /// Illustrative reading, kept in a realistic 60–70 band: a first honest
    /// scan rarely reads higher, and an over-bright sample sets a promise the
    /// real reveal cannot match. Overall ≈ the average of the five sub-scores,
    /// because a headline figure that does not follow from the rows under it
    /// is the first thing a sceptical reader catches.
    private static let overall = 66
    private static let subs: [(String, Int)] = [
        ("Glow", 69),
        ("Hydration", 63),
        ("Texture", 65),
        ("Redness", 61),
        ("Evenness", 68),
    ]

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // Fixed, not flexible. Three flexible spacers in one
                    // column share the slack equally, so a `minLength`
                    // spacer here would grow with the others and push the
                    // first element away from the header on a tall canvas.
                    Spacer().frame(height: RampStage.headerClearance)

                    Text("Your skin,\nfully read.")
                        .font(RampStage.serif(26))
                        .foregroundStyle(RampStage.ink)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: VSpace.lg)

                    chartCard
                        .padding(.horizontal, VSpace.xl)

                    Spacer(minLength: VSpace.lg)

                    // Stays, and stays visible. The card is a mock-up of a
                    // measurement, which is exactly the kind of thing a reader
                    // is entitled to mistake for their own result.
                    Text("Illustrative reading. Yours is built from your scan.")
                        .font(VType.micro)
                        .foregroundStyle(RampStage.textTertiary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)

                    RampPrimaryButton(title: "I want mine") { onAdvance() }
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.md)
                    Spacer().frame(height: VSpace.xxl)
                }
                .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .task {
            if reduceMotion { reveal = 1; return }
            try? await Task.sleep(for: .milliseconds(420))
            // The SAME stepped count-up the real results run: discrete ticks
            // through withAnimation so the monospaced digits genuinely roll,
            // decelerating as they land — not one long linear morph.
            let steps = 26
            for i in 1...steps {
                let t = Double(i) / Double(steps)
                withAnimation(.linear(duration: 0.05)) {
                    reveal = 1 - pow(1 - t, 2.4)
                }
                if i % 2 == 0 { Haptics.fire(.tick) }
                try? await Task.sleep(for: .seconds(0.026 + 0.055 * t))
                if Task.isCancelled { return }
            }
            withAnimation(.easeOut(duration: 0.12)) { reveal = 1 }
        }
    }

    /// The card: circular photo straddling the top of the reading — the real
    /// results layout.
    private var chartCard: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                heroScore

                Rectangle()
                    .fill(RampStage.hair)
                    .frame(height: 1)
                    .padding(.vertical, VSpace.md)

                VStack(spacing: 14) {
                    ForEach(Self.subs.indices, id: \.self) { i in
                        subRow(Self.subs[i].0, Self.subs[i].1)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 74)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: RampStage.ink.opacity(0.16), radius: 26, y: 14)

            avatar
                .offset(y: -56)
        }
        .padding(.top, 56)
    }

    /// The figure the product is actually about, set at the size that says so.
    private var heroScore: some View {
        let shown = Int((Double(Self.overall) * reveal).rounded())
        return VStack(spacing: 2) {
            Text("OVERALL")
                .font(VType.micro)
                .tracking(3)
                .foregroundStyle(RampStage.accentDeep)

            // The iOS-teaser look that RESOLVES: the number starts blurred and
            // sharpens as it counts up, just like the real reveal — not a
            // permanent smudge sitting over the card.
            Text(verbatim: "\(shown)")
                .font(.system(size: 72, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(RampStage.ink)
                .contentTransition(.numericText(value: Double(shown)))
                .blur(radius: 12 * (1 - reveal))

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(RampStage.hair.opacity(0.7))
                    Capsule()
                        .fill(RampStage.accentGradient)
                        .frame(width: proxy.size.width * CGFloat(shown) / 100)
                }
            }
            .frame(height: 8)
            .padding(.top, 8)
            .blur(radius: 4 * (1 - reveal))
            .opacity(0.7 + 0.3 * reveal)
        }
    }

    /// A sub-score. Label column fixed so the five bars share one left edge —
    /// ragged bar starts turn a reading into a bar chart nobody can compare
    /// across.
    private func subRow(_ label: String, _ value: Int) -> some View {
        let shown = Int((Double(value) * reveal).rounded())
        return HStack(spacing: 12) {
            Text(LocalizedStringKey(label))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(RampStage.textSecondary)
                .lineLimit(1)
                .frame(width: 76, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(RampStage.hair.opacity(0.7))
                    // Only the pale fill needs bounding; it sits at about
                    // 1.2:1 against the track, so the bar's length would be
                    // guesswork without the outline.
                    Capsule()
                        .fill(RampStage.accent)
                        .overlay(Capsule().strokeBorder(RampStage.accentEdge, lineWidth: 1))
                        .frame(width: proxy.size.width * CGFloat(shown) / 100)
                }
            }
            .frame(height: 6)
            .blur(radius: 3 * (1 - reveal))
            .opacity(0.7 + 0.3 * reveal)

            Text(verbatim: "\(shown)")
                .font(.system(size: 15, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(RampStage.ink)
                .contentTransition(.numericText(value: Double(shown)))
                .frame(width: 26, alignment: .trailing)
        }
    }

    /// The example face, in a ringed circle — exactly like the captured avatar
    /// on the real results screen.
    private var avatar: some View {
        Group {
            #if canImport(UIKit)
            if let ui = RampPhoto.load("SampleFace") {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                Circle().fill(RampStage.accent)
            }
            #else
            Circle().fill(RampStage.accent)
            #endif
        }
        // `.top` — a tall portrait filled into a small circle otherwise
        // crops to its vertical midpoint, which lands around the collar on
        // a head-and-shoulders photo, not the face. See the same note on
        // `RampIntroReadingScreen.avatar`.
        .frame(width: 108, height: 108, alignment: .top)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.white, lineWidth: 4))
        .overlay(Circle().strokeBorder(RampStage.accent, lineWidth: 4).padding(-4))
        .shadow(color: RampStage.ink.opacity(0.20), radius: 14, y: 8)
    }
}
