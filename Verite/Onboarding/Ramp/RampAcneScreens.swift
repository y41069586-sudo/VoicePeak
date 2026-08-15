import SwiftUI

// ============================================================
// MARK: — The acne-specific screens
// ============================================================
//
// Four screens that exist for one reason each, and each takes a DIFFERENT
// shape. Six identical tile-lists in a row is what makes a long quiz feel
// long; varying the input is what keeps a 25-screen flow moving.
//
//   RampAcneTypeScreen  — multi-select over photographs. Naming your own kind
//                         of acne is more specific than "breakouts", and the
//                         plan can actually branch on it.
//   RampSpendScreen     — a slider. What you already spend every month is the
//                         number every later price is judged against; asking
//                         it here means the paywall lands next to it.
//   RampCycleScreen     — no input at all. It names the loop — new product,
//                         no result, more money, repeat — and turns it into
//                         the argument for a plan.
//   RampGoalScreen      — the goal-setting act. The sentence chosen here is
//                         repeated by the curve, the plan and the paywall.

// ============================================================
// MARK: — Which kind of acne (multi-select over photos)
// ============================================================

/// Photo tiles, two per row, multi-select, with a Continue that stays disabled
/// until something is picked. Five photographed presentations — blackheads,
/// whiteheads, papules, cysts, scarring — plus an opt-out for anyone who
/// cannot name theirs. The photos are supplied assets in `Resources/Photos/`;
/// until a file exists that tile draws a placeholder, so the screen ships and
/// works before the photography does.
///
/// Scarring earns its tile by not being active acne at all. Somebody whose
/// breakouts have stopped but whose marks have not is a different plan and a
/// different promise, and without this tile they would have to claim a lesion
/// they no longer have.
///
/// ONE HARD RULE FOR THE PHOTOGRAPHS: macro crops of skin only — no face, no
/// eyes, no jawline, nothing that identifies a person. It is not a style note.
/// A recognisable person shown as having a skin condition engages personality
/// rights, and the stock libraries put exactly that case behind a separate
/// "sensitive use" licence that a standard purchase does NOT include — so a
/// face here would breach the licence we bought, quite apart from any claim
/// the person could bring. Cropped to skin, none of that attaches. It also
/// happens to be the better tile: these frames are wider than they are tall.
struct RampAcneTypeScreen: View {
    @Binding var selected: Set<String>
    let onAdvance: () -> Void

    struct AcneType: Identifiable {
        let id: String
        let label: String
        /// nil on the opt-out tile — there is nothing to photograph.
        let photo: String?
        let hint: String
    }

    /// The opt-out. Anyone who cannot name what they have needs a way past
    /// this screen: Continue is disabled until something is picked, so
    /// without it an uncertain user is simply stuck — on a screen that comes
    /// second in the flow, before we have given them anything.
    static let unsureID = "unsure"

    static let types: [AcneType] = [
        AcneType(id: "blackheads", label: "Blackheads",
                 photo: "AcneBlackheads", hint: "Open, dark pores"),
        AcneType(id: "whiteheads", label: "Whiteheads",
                 photo: "AcneWhiteheads", hint: "Small closed bumps"),
        AcneType(id: "papules", label: "Red bumps",
                 photo: "AcnePapules", hint: "Sore, no head"),
        AcneType(id: "cysts", label: "Deep, painful",
                 photo: "AcneCysts", hint: "Under the skin"),
        AcneType(id: "scars", label: "Marks & scars",
                 photo: "AcneScars", hint: "Left behind after healing"),
        AcneType(id: unsureID, label: "Not sure",
                 photo: nil, hint: "The scan will tell us"),
    ]

    private let columns = [GridItem(.flexible(), spacing: 12),
                           GridItem(.flexible(), spacing: 12)]

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: VSpace.xxl)

                    Text("WHERE WE START")
                        .font(VType.micro).tracking(3)
                        .foregroundStyle(RampStage.accentDeep)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.bottom, VSpace.sm)

                    Text("What does yours\nlook like?")
                        .font(RampStage.serif(25))
                        .foregroundStyle(RampStage.ink)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)

                    Text("Pick everything you recognise — most skin has more than one kind. Not sure is a fine answer.")
                        .font(VType.body)
                        .foregroundStyle(RampStage.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.xs)

                    Spacer().frame(height: VSpace.lg)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Self.types) { type in
                            tile(type)
                        }
                    }
                    .padding(.horizontal, VSpace.lg)

                    Spacer(minLength: VSpace.xl)

                    RampPrimaryButton(title: "Continue", isEnabled: !selected.isEmpty) {
                        onAdvance()
                    }
                    .padding(.horizontal, VSpace.lg)

                    Spacer().frame(height: VSpace.xxl)
                }
                .frame(minHeight: proxy.size.height, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func tile(_ type: AcneType) -> some View {
        let isOn = selected.contains(type.id)
        return Button {
            Haptics.fire(.selection)
            withAnimation(VMotion.snappy) {
                if type.id == Self.unsureID {
                    // Claiming uncertainty clears every specific answer.
                    selected = isOn ? [] : [Self.unsureID]
                } else {
                    selected.remove(Self.unsureID)
                    if isOn { selected.remove(type.id) } else { selected.insert(type.id) }
                }
            }
        } label: {
            VStack(spacing: 0) {
                Group {
                    if let photo = type.photo {
                        RampAcnePhoto(name: photo)
                    } else {
                        ZStack {
                            RampStage.accentSoft
                            Image(systemName: "questionmark")
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(RampStage.accentDeep)
                        }
                    }
                }
                    .frame(height: 116)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        if isOn { addedBadge.padding(8) }
                    }
                    .padding(8)

                VStack(spacing: 1) {
                    Text(LocalizedStringKey(type.label))
                        .font(VType.bodyLarge.weight(.semibold))
                        .foregroundStyle(RampStage.ink)
                    Text(LocalizedStringKey(type.hint))
                        .font(VType.caption)
                        .foregroundStyle(RampStage.textSecondary)
                }
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity)
            // White always — separation is shadow, selection is the ring
            // plus the ADDED badge, not a tinted card.
            .background(RampStage.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .rampCardShadow()
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isOn ? RampStage.accentEdge : Color.clear, lineWidth: 2))
        }
        .buttonStyle(PressableStyle())
    }

    private var addedBadge: some View {
        Text("ADDED")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(0.3)
            .foregroundStyle(RampStage.accentDeep)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RampStage.accentSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// A supplied close-up if one exists, otherwise a soft warm placeholder that
/// reads as "photo pending" rather than as a broken tile.
private struct RampAcnePhoto: View {
    let name: String

    var body: some View {
        Group {
            #if canImport(UIKit)
            if let image = RampPhoto.load(name) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                placeholder
            }
            #else
            placeholder
            #endif
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(colors: [RampStage.dawnPeach, RampStage.glow],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "photo")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(RampStage.accentEdge.opacity(0.7))
        }
    }
}

// ============================================================
// MARK: — What you already spend (the anchor)
// ============================================================

/// One slider over six buckets. This is the number every later price is
/// measured against: somebody who just told you they spend €50–80 a month on
/// products that did not work reads a subscription very differently from
/// somebody who was never asked.
///
/// The buckets are shown in the device's own currency and never stored as an
/// amount — it is an anchor and a segmentation signal, not billing data.
struct RampSpendScreen: View {
    @Binding var bucket: Int
    let onAdvance: () -> Void

    /// Lower bounds; the last bucket is open-ended.
    private let bounds = [0, 10, 25, 50, 80, 120]

    private var label: String {
        let currency = Locale.current.currencySymbol ?? "$"
        if bucket <= 0 { return String(localized: "Nothing yet") }
        if bucket >= bounds.count - 1 { return "\(currency)\(bounds[bounds.count - 1])+" }
        return "\(currency)\(bounds[bucket])–\(bounds[bucket + 1])"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: VSpace.xxl)

            Text("YOUR LIFE · SIX OF SIX")
                .font(VType.micro).tracking(3)
                .foregroundStyle(RampStage.accentDeep)
                .padding(.horizontal, VSpace.lg)
                .padding(.bottom, VSpace.sm)

            Text("What do you spend\non your skin a month?")
                .font(RampStage.serif(25))
                .foregroundStyle(RampStage.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, VSpace.lg)

            Text("Roughly is fine. Cleansers, creams, treatments — everything you've been trying.")
                .font(VType.body)
                .foregroundStyle(RampStage.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, VSpace.lg)
                .padding(.top, VSpace.xs)

            Spacer()

            Text(verbatim: label)
                .font(.system(size: 40, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(RampStage.ink)
                .frame(maxWidth: .infinity)
                .contentTransition(.numericText(value: Double(bucket)))
                .animation(VMotion.snappy, value: bucket)

            segmentedSlider
                .padding(.horizontal, VSpace.xl)
                .padding(.top, VSpace.lg)

            Spacer()

            RampPrimaryButton(title: "Continue") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
    }

    /// Six segments rather than a continuous track: the answer is a bucket, and
    /// a continuous slider would imply a precision nobody has about this.
    private var segmentedSlider: some View {
        GeometryReader { proxy in
            let count = bounds.count
            let gap: CGFloat = 6
            let segment = (proxy.size.width - gap * CGFloat(count - 1)) / CGFloat(count)
            ZStack(alignment: .leading) {
                HStack(spacing: gap) {
                    ForEach(0..<count, id: \.self) { index in
                        Capsule()
                            .fill(index <= bucket ? RampStage.accentEdge : RampStage.hair)
                            .frame(height: 10)
                    }
                }
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().strokeBorder(RampStage.accentEdge, lineWidth: 2))
                    .shadow(color: RampStage.ink.opacity(0.18), radius: 6, y: 2)
                    .frame(width: 30, height: 30)
                    .offset(x: (segment + gap) * CGFloat(bucket) + segment / 2 - 15)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let step = (segment + gap)
                        let raw = Int(((value.location.x) / step).rounded(.down))
                        let clamped = max(0, min(count - 1, raw))
                        if clamped != bucket {
                            bucket = clamped
                            Haptics.fire(.tick)
                        }
                    }
            )
        }
        .frame(height: 44)
        .accessibilityElement()
        .accessibilityLabel("Monthly spend")
        .accessibilityValue(label)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: bucket = min(bounds.count - 1, bucket + 1)
            case .decrement: bucket = max(0, bucket - 1)
            @unknown default: break
            }
        }
    }
}

// ============================================================
// MARK: — The loop you're already in
// ============================================================

/// No input. It names the cycle the user recognises from their own bathroom
/// shelf — buy something new, wait, see nothing, buy something else — and
/// turns it into the case for a plan. Placed directly after the spend
/// question, so the money they just named is still on the screen behind them.
struct RampCycleScreen: View {
    let onAdvance: () -> Void

    @State private var shown = false

    private let loop: [(icon: String, title: String)] = [
        ("cart", "Buy something new"),
        ("clock", "Wait a few weeks"),
        ("questionmark", "See no real change"),
        ("arrow.triangle.2.circlepath", "Start again"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: VSpace.xxl)

            Text("WHY IT KEEPS COMING BACK")
                .font(VType.micro).tracking(3)
                .foregroundStyle(RampStage.accentDeep)
                .padding(.horizontal, VSpace.lg)
                .padding(.bottom, VSpace.sm)

            Text("Products aren't\nthe problem.")
                .font(RampStage.serif(25))
                .foregroundStyle(RampStage.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, VSpace.lg)

            Text("Without knowing what changed and why, every new product is another guess — and the loop starts over.")
                .font(VType.body)
                .foregroundStyle(RampStage.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, VSpace.lg)
                .padding(.top, VSpace.xs)

            Spacer()

            VStack(spacing: 0) {
                ForEach(Array(loop.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(RampStage.accentSoft)
                                .frame(width: 38, height: 38)
                            Image(systemName: item.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(RampStage.accentDeep)
                        }
                        Text(LocalizedStringKey(item.title))
                            .font(VType.bodyLarge)
                            .foregroundStyle(RampStage.ink)
                        Spacer(minLength: 0)
                    }
                    .opacity(shown ? 1 : 0)
                    .offset(y: shown ? 0 : 8)
                    .animation(VMotion.gentle.delay(Double(index) * 0.12), value: shown)

                    if index < loop.count - 1 {
                        Rectangle()
                            .fill(RampStage.hair)
                            .frame(width: 1.5, height: 22)
                            .padding(.leading, 18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .opacity(shown ? 1 : 0)
                            .animation(VMotion.gentle.delay(Double(index) * 0.12 + 0.06), value: shown)
                    }
                }
            }
            .padding(.horizontal, VSpace.xl)

            // The closing line: the loop above, answered.
            Text("A plan breaks it. It remembers what you used, what your skin did, and what to change next.")
                .font(VType.body)
                .foregroundStyle(RampStage.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, VSpace.lg)
                .padding(.top, VSpace.xl)
                .opacity(shown ? 1 : 0)
                .animation(VMotion.gentle.delay(0.6), value: shown)

            Spacer()

            RampPrimaryButton(title: "Continue") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
        .onAppear { shown = true }
    }
}

// ============================================================
// MARK: — The goal (what the paywall will hand back)
// ============================================================

/// Statement tiles rather than a labelled list: the user is choosing a
/// sentence to own, and the wording is repeated verbatim later — the curve,
/// the plan preview and the paywall all read this back. Selecting advances.
struct RampGoalScreen: View {
    let selected: RampQuizAnswers.Goal?
    let onSelect: (RampQuizAnswers.Goal) -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: VSpace.xxl)

                    Text("WHAT BETTER LOOKS LIKE")
                        .font(VType.micro).tracking(3)
                        .foregroundStyle(RampStage.accentDeep)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.bottom, VSpace.sm)

                    Text("In 14 days,\nwhat would you notice?")
                        .font(RampStage.serif(25))
                        .foregroundStyle(RampStage.ink)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)

                    Text("Pick the one that would actually matter to you. Your plan is built toward it.")
                        .font(VType.body)
                        .foregroundStyle(RampStage.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.xs)

                    Spacer().frame(height: VSpace.xl)

                    VStack(spacing: VSpace.sm) {
                        ForEach(RampQuizAnswers.Goal.allCases) { goal in
                            RampOptionCard(label: goal.label,
                                           icon: goal.icon,
                                           selected: selected == goal) {
                                onSelect(goal)
                            }
                        }
                    }
                    .padding(.horizontal, VSpace.lg)

                    Spacer(minLength: VSpace.xxl)
                }
                .frame(minHeight: proxy.size.height, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

// ============================================================
// MARK: — What we heard (the acne chapter's closing beat)
// ============================================================

/// The interstitial that closes the acne chapter, and the emotional peak of
/// the first third of the flow.
///
/// It exists because of a specific hole: the user named their acne on screen
/// two, and screen three used to be a product demo. Four questions later
/// they had been asked a lot and told nothing. This screen is the reply —
/// their own answers held up as chips, then one sentence that is ABOUT them
/// rather than about us.
///
/// Two rules for anything edited into this file:
///
///  1. No numbers. "87% of people with cystic acne…" is the easiest line to
///     write here and the one that would make every honest claim elsewhere
///     in the app worth less. The copy in `acneEmpathyHeadline` /
///     `acneEmpathyBody` is derived purely from what the user just told us.
///  2. No promise. This screen does not say the plan will work — the
///     screens after it make the (measured, hedged) case. It says we heard
///     them, and stops.
struct RampAcneEmpathyScreen: View {
    let headline: String
    let message: String
    /// The user's own answers, echoed back.
    var chips: [String] = []
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var recapIn = false
    @State private var chipsShown = 0
    @State private var headlineIn = false
    @State private var messageIn = false
    @State private var buttonIn = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: VSpace.xl)

                    recap
                        .padding(.horizontal, VSpace.lg)

                    // The one big break on the screen. Everything above it is
                    // a restatement of what the user already chose; everything
                    // below is the only thing here they haven't seen. Two
                    // groups, one gap — not four evenly-spaced blocks.
                    Spacer().frame(height: 30)

                    // The sentence IS the screen, so it is set like one — 36pt
                    // against the old 28. That size is not decoration: this
                    // page carries one short line and a paragraph, and at 28
                    // the composition didn't fill the canvas, it floated in
                    // the middle of it with dead space above and below. Type
                    // that occupies the space it's given is the difference
                    // between "sparse on purpose" and "unfinished".
                    Text(LocalizedStringKey(headline))
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(RampStage.ink)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(headlineIn ? 1 : 0)
                        .offset(y: headlineIn ? 0 : 12)
                        .padding(.horizontal, VSpace.lg)

                    Text(LocalizedStringKey(message))
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(RampStage.textSecondary)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        // Held to a readable measure rather than the full
                        // gutter width. Body this size running the whole way
                        // across a large phone is a ~60-character line, which
                        // is where the eye starts losing its place between
                        // rows.
                        .frame(maxWidth: 330, alignment: .leading)
                        .opacity(messageIn ? 1 : 0)
                        .offset(y: messageIn ? 0 : 8)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.md)

                    Spacer(minLength: VSpace.xl)

                    RampPrimaryButton(title: "Continue") { onAdvance() }
                        .padding(.horizontal, VSpace.lg)
                        .opacity(buttonIn ? 1 : 0)

                    Spacer().frame(height: VSpace.xxl)
                }
                .frame(minHeight: proxy.size.height, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        // One soft pool of warmth behind the headline. The flow's ground is
        // flat white, which is right for the screens made of white cards —
        // but this screen has no cards, just type, and on bare white that
        // reads as a blank page someone forgot to finish. The glow is scoped
        // to this screen for exactly that reason: it gives the type something
        // to sit on without putting an uneven ground back under the tiles
        // everywhere else. Kept low enough to read as light, never as a
        // coloured shape.
        .background(alignment: .topLeading) {
            RadialGradient(colors: [RampStage.accent.opacity(0.45), .clear],
                           center: .center, startRadius: 0, endRadius: 300)
                .frame(width: 600, height: 600)
                .offset(x: -150, y: 60)
                .allowsHitTesting(false)
                .ignoresSafeArea()
        }
        .task { await run() }
    }

    /// Eyebrow and chips, one unit. Six points apart — barely more than the
    /// eyebrow's own line height — so they read as a single caption rather
    /// than as two separate things that happen to be stacked.
    private var recap: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHAT WE HEARD")
                .font(VType.micro)
                .tracking(3)
                .foregroundStyle(RampStage.accentDeep)

            if !chips.isEmpty {
                let row = HStack(spacing: 6) {
                    ForEach(chips.indices, id: \.self) { i in
                        Text(LocalizedStringKey(chips[i]))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(RampStage.accentDeep)
                            .lineLimit(1)
                            .padding(.horizontal, 10).padding(.vertical, 5.5)
                            // Lighter than the old solid fill: these are a
                            // footnote under a 36pt headline, and at full
                            // strength three of them out-shouted it.
                            .background(RampStage.accent.opacity(0.55), in: Capsule())
                            .opacity(i < chipsShown ? 1 : 0)
                            .scaleEffect(i < chipsShown ? 1 : 0.6)
                    }
                }
                ViewThatFits(in: .horizontal) {
                    row
                    ScrollView(.horizontal) { row }
                        .scrollIndicators(.hidden)
                }
            }
        }
        .opacity(recapIn ? 1 : 0)
        .offset(y: recapIn ? 0 : 6)
    }

    private func run() async {
        if reduceMotion {
            recapIn = true; chipsShown = chips.count
            headlineIn = true; messageIn = true; buttonIn = true
            return
        }
        withAnimation(VMotion.gentle) { recapIn = true }
        // `chips` can legitimately be empty (nothing recognised on the photo
        // grid, nothing tried) — stepping 1...1 there would fire a haptic for
        // a chip that never appears.
        for i in chips.indices {
            try? await Task.sleep(for: .milliseconds(110))
            guard !Task.isCancelled else { return }
            withAnimation(VMotion.snappy) { chipsShown = i + 1 }
            Haptics.fire(.tick)
        }
        try? await Task.sleep(for: .milliseconds(180))
        guard !Task.isCancelled else { return }
        withAnimation(VMotion.gentle) { headlineIn = true }
        try? await Task.sleep(for: .milliseconds(260))
        guard !Task.isCancelled else { return }
        withAnimation(VMotion.gentle) { messageIn = true }
        try? await Task.sleep(for: .milliseconds(240))
        guard !Task.isCancelled else { return }
        withAnimation(VMotion.gentle) { buttonIn = true }
    }
}

// ============================================================
// MARK: — What you've already tried
// ============================================================

/// Multi-select over the things people actually reach for before an app.
/// Continue is never disabled — picking nothing IS the answer for anyone at
/// the very start, and "Nothing yet" says so explicitly rather than leaving
/// them guessing whether an empty screen counts.
///
/// This is the question that buys the most goodwill in the whole flow, for a
/// reason worth keeping in mind while editing it: everyone who has had acne
/// for more than a year has been sold the same first thing repeatedly. Being
/// asked what already failed — before anything is recommended — is the
/// clearest possible signal that the recommendation to come is not going to
/// be that same first thing again.
struct RampAcneTriedScreen: View {
    @Binding var selected: Set<String>
    let onAdvance: () -> Void

    private let options = RampQuizAnswers.AcneTried.allCases

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: VSpace.xxl)

                    Text("YOUR ACNE · TWO OF THREE")
                        .font(VType.micro).tracking(3)
                        .foregroundStyle(RampStage.accentDeep)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.bottom, VSpace.sm)

                    Text("What have you\nalready tried?")
                        .font(RampStage.serif(25))
                        .foregroundStyle(RampStage.ink)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)

                    Text("Pick everything. Knowing what didn't hold is how we avoid handing you the same thing again.")
                        .font(VType.body)
                        .foregroundStyle(RampStage.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.xs)

                    Spacer().frame(height: VSpace.xl)

                    VStack(spacing: VSpace.sm) {
                        ForEach(options) { option in
                            RampOptionCard(
                                label: option.label,
                                icon: option.icon,
                                selected: selected.contains(option.rawValue)
                            ) {
                                toggle(option.rawValue)
                            }
                        }
                        // The opt-out, mirroring the sensitivity screen's
                        // "Nothing I know of": clears every flag.
                        RampOptionCard(
                            label: "Nothing yet",
                            icon: "circle.dashed",
                            selected: selected.isEmpty
                        ) {
                            Haptics.fire(.selection)
                            selected.removeAll()
                        }
                    }
                    .padding(.horizontal, VSpace.lg)

                    Spacer(minLength: VSpace.xl)

                    RampPrimaryButton(title: "Continue") { onAdvance() }
                        .padding(.horizontal, VSpace.lg)
                    Spacer().frame(height: VSpace.xxl)
                }
                .frame(minHeight: proxy.size.height, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func toggle(_ raw: String) {
        Haptics.fire(.selection)
        if selected.contains(raw) { selected.remove(raw) } else { selected.insert(raw) }
    }
}
