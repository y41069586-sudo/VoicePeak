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
/// the person could bring. Cropped to skin, none of that attaches.
///
/// The tile crops each frame to a SQUARE sized off the column. The supplied
/// files are landscape, but they are pure texture — there is no subject to
/// lose — and a square is what stops the grid reading as six letterboxed
/// bands with their labels crushed underneath.
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

    private let columns = [GridItem(.flexible(), spacing: RampStage.tileGap),
                           GridItem(.flexible(), spacing: RampStage.tileGap)]

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: RampStage.headerClearance)

                    Text("What does yours\nlook like?")
                        .font(RampStage.serif(26, weight: .semibold))
                        .foregroundStyle(RampStage.ink)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)

                    Text("Pick everything you recognise.")
                        .font(VType.body)
                        .foregroundStyle(RampStage.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.xs)

                    Spacer().frame(height: VSpace.lg)

                    LazyVGrid(columns: columns, spacing: RampStage.tileGap) {
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
                // Square, sized off the column — not a fixed 116pt strip. At
                // that height the photo was a letterbox band with the label
                // crammed under it, and a grid of six read as squashed
                // however much gap sat between the tiles. A square is also
                // the crop these macro frames want: they are pure texture, so
                // nothing is lost.
                //
                // THE SQUARE IS DRIVEN BY `Color.clear`, NOT BY THE PHOTO, and
                // that is load-bearing. `RampPhoto.load` builds its image with
                // `UIImage(contentsOfFile:)`, which returns scale 1.0 — so a
                // 900px JPEG reports an intrinsic size of 900×900 POINTS.
                // `Image.resizable()` keeps that as its ideal size, and a grid
                // row proposes no height, so `.aspectRatio(1, .fit)` applied
                // over the photo resolved against that 900pt ideal instead of
                // against the column. Every tile then demanded ~900pt inside a
                // ~170pt column; `LazyVGrid` still placed the columns at their
                // own fixed offsets, so the tiles drew straight over each
                // other and the right one clipped the left one's photo and
                // pick mark. `Color.clear` has no ideal size of its own, so
                // the square can only come from the proposal — the column.
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        if let photo = type.photo {
                            RampAcnePhoto(name: photo)
                        } else {
                            ZStack {
                                // `accent`, not `accentSoft`: the tile's own
                                // background turns accentSoft when picked, and
                                // this stand-in would dissolve into it.
                                RampStage.accent
                                Image(systemName: "questionmark")
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundStyle(RampStage.accentDeep)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        pickMark(isOn).padding(10)
                    }
                    .padding(10)

                VStack(spacing: 3) {
                    Text(LocalizedStringKey(type.label))
                        .font(VType.bodyLarge.weight(.semibold))
                        .foregroundStyle(RampStage.ink)
                    Text(LocalizedStringKey(type.hint))
                        .font(VType.caption)
                        .foregroundStyle(RampStage.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.top, 2)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)
            // Hairline, not shadow — same language as `RampOptionCard`. A
            // grid of shadowed tiles reads as six floating objects; a grid of
            // outlined ones reads as one set of choices.
            .background(isOn ? RampStage.accentSoft : RampStage.card,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(isOn ? RampStage.accentEdge : RampStage.hair,
                              lineWidth: isOn ? 2 : 1))
        }
        .buttonStyle(PressableStyle())
    }

    /// The pick marker, sitting on the photo's top-right corner. Present
    /// whether or not the tile is chosen — an empty white disc reads as
    /// "tappable", and the tick then lands IN it instead of appearing out of
    /// nowhere. (This replaced an "ADDED" text badge, which said the same
    /// thing in five times the ink and only after the fact.)
    private func pickMark(_ isOn: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isOn ? RampStage.accentEdge : Color.white.opacity(0.92))
                .frame(width: 24, height: 24)
                .shadow(color: RampStage.ink.opacity(0.12), radius: 4, y: 1)
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.white)
                .opacity(isOn ? 1 : 0)
        }
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
// MARK: — The loop you're already in
// ============================================================

/// The loop, drawn as a loop — and running.
///
/// It used to be a vertical LIST of four steps, which is the one shape that is
/// not a cycle: a list has a top, a bottom and a way out. The reader had to be
/// told in prose that it comes back around, because the drawing said the
/// opposite. Four stops on a closed circuit say it without a caption.
///
/// THE CIRCULATION IS THE POINT, AND SO IS STOPPING IT. The current runs the
/// circuit twice — arrow by arrow, hub turning — and then halts on the exact
/// beat the payoff line arrives. Motion stopping is the argument: the loop
/// does not end because you tried harder, it ends when something finally keeps
/// a record. A static diagram has to be read as a cycle; one that visibly
/// comes back to its first tile and then stops has already made the case.
///
/// THE CHROME STAYS NEUTRAL. The emoji carry the colour, but the tiles,
/// arrows and hub are drawn in hairline and ink. Everywhere else in this flow
/// the accent means "ours" or "the way out" — rendering the circuit in brand
/// orange would dress the thing this screen argues against in our own colour,
/// and the four stops would read as features. The first accent on the screen
/// appears only once the loop has stopped.
///
/// IT ALSO HAS TO CLOSE ITS OWN ARGUMENT NOW. It used to name the loop and
/// leave the answer to the screen after it. Since the reorder `skinProgress`
/// runs BEFORE this one and the next screen is a question, so the payoff below
/// the circuit is the only place the case is ever made.
struct RampCycleScreen: View {
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var tilesIn = 0
    @State private var circuitIn = false
    /// Which leg the current is on, 0…3 clockwise from the top. `nil` once the
    /// loop has been stopped for good.
    @State private var live: Int?
    @State private var spin: Double = 0
    @State private var payoffIn = false

    private struct Stop {
        let emoji: String
        let title: String
    }

    /// Clockwise from the top left, and the order IS the argument — so the
    /// grid lays these out 0,1 across the top and 3,2 across the bottom rather
    /// than in reading order.
    ///
    /// Every emoji here carries default EMOJI presentation, so none of them
    /// needs a U+FE0F selector to render in colour (a `🌤` on the skin-progress
    /// screen fell back to a hollow glyph box for exactly that reason).
    ///
    /// 🪞 rather than a question mark for "see no change": this is a skincare
    /// funnel, and the mirror is where that verdict actually gets delivered.
    /// 💸 rather than a trolley for the first stop, because the money is the
    /// part of the loop that stings and there is no longer a spend screen
    /// anywhere in the flow to say it.
    ///
    /// 🌀 rather than the obvious 🔁 for the last stop, and the reason is
    /// colour rather than meaning. 🔁 renders in almost exactly this app's
    /// accent orange — it became the most saturated thing on a deliberately
    /// grey screen, sitting a thumb away from an orange button, and pulled
    /// the eye to "Start again" as though that were the point being sold.
    private static let stops: [Stop] = [
        Stop(emoji: "💸", title: "Buy something new"),
        Stop(emoji: "⏳", title: "Wait a few weeks"),
        Stop(emoji: "🪞", title: "See no change"),
        Stop(emoji: "🌀", title: "Start again"),
    ]

    /// Wide enough that the arrows sit IN the gaps with room to move rather
    /// than pressed against the tiles — the circuit only reads if its
    /// connectors have space of their own.
    private static let gap: CGFloat = 30

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: RampStage.headerClearance)

                    Text("Products aren't\nthe problem.")
                        .font(RampStage.serif(26, weight: .semibold))
                        .foregroundStyle(RampStage.ink)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)

                    Text("Not knowing what changed is.")
                        .font(VType.body)
                        .foregroundStyle(RampStage.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.xs)

                    Spacer(minLength: VSpace.lg)

                    circuit
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.md)

                    Spacer(minLength: VSpace.lg)

                    payoff
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.md)

                    Spacer(minLength: VSpace.lg)

                    RampPrimaryButton(title: "Continue") { onAdvance() }
                        .padding(.horizontal, VSpace.lg)
                    Spacer().frame(height: VSpace.xxl)
                }
                .frame(minHeight: proxy.size.height, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .task { await choreograph() }
    }

    // MARK: The circuit

    private var circuit: some View {
        VStack(spacing: Self.gap) {
            HStack(spacing: Self.gap) { tile(0); tile(1) }
            HStack(spacing: Self.gap) { tile(3); tile(2) }
        }
        .overlay { connectors }
        .accessibilityElement()
        .accessibilityLabel("A loop that keeps returning to its start: buy something new, wait a few weeks, see no change, start again.")
    }

    /// The four arrows and the hub, positioned into the gaps the grid leaves.
    /// Derived from the measured size rather than from constants, so they stay
    /// on the crossing whatever the tiles grow to.
    private var connectors: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let colCentre = (w - Self.gap) / 4   // centre of one column
            let rowCentre = (h - Self.gap) / 4   // centre of one row

            ZStack {
                arrow(0, "arrow.right", at: CGPoint(x: w / 2, y: rowCentre),
                      nudge: CGSize(width: 3, height: 0))
                arrow(1, "arrow.down", at: CGPoint(x: w - colCentre, y: h / 2),
                      nudge: CGSize(width: 0, height: 3))
                arrow(2, "arrow.left", at: CGPoint(x: w / 2, y: h - rowCentre),
                      nudge: CGSize(width: -3, height: 0))
                arrow(3, "arrow.up", at: CGPoint(x: colCentre, y: h / 2),
                      nudge: CGSize(width: 0, height: -3))
                hub.position(x: w / 2, y: h / 2)
            }
            .opacity(circuitIn ? 1 : 0)
        }
        .allowsHitTesting(false)
    }

    /// One leg of the circuit. When the current reaches it the arrow darkens,
    /// grows and slides a little the way it points — small enough to read as
    /// flow rather than as four separate blinking icons.
    private func arrow(_ index: Int, _ symbol: String,
                       at point: CGPoint, nudge: CGSize) -> some View {
        let isLive = live == index
        return Image(systemName: symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isLive ? RampStage.inkSoft : RampStage.inkFaint)
            .scaleEffect(isLive ? 1.25 : 1)
            .offset(isLive ? nudge : .zero)
            .position(point)
    }

    /// Sits on the crossing of both gaps and turns while the current runs —
    /// the one moving part that says "again" without a word. Left as a grey
    /// symbol rather than a 🔁 so it cannot be mistaken for a fifth stop.
    private var hub: some View {
        Image(systemName: "arrow.triangle.2.circlepath")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(RampStage.inkFaint)
            .frame(width: 38, height: 38)
            .background(Circle().fill(RampStage.card))
            .overlay(Circle().strokeBorder(RampStage.hair, lineWidth: 1))
            .rotationEffect(.degrees(spin))
    }

    private func tile(_ index: Int) -> some View {
        let stop = Self.stops[index]
        let isHere = live == index
        let arrived = index < tilesIn

        return VStack(spacing: VSpace.sm) {
            Text(stop.emoji)
                .font(.system(size: 26))
                .frame(width: 50, height: 50)
                .background(Circle().fill(RampStage.recess))
                // A ring that only appears under the current, so the emoji
                // well reads as the thing being visited.
                .overlay(Circle().strokeBorder(isHere ? RampStage.inkFaint : .clear,
                                               lineWidth: 1.5))

            Text(LocalizedStringKey(stop.title))
                .font(VType.bodyMedium)
                .foregroundStyle(RampStage.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VSpace.md)
        .padding(.horizontal, VSpace.sm)
        .background(RampStage.card,
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(RampStage.hair, lineWidth: 1))
        .shadow(color: RampStage.ink.opacity(isHere ? 0.10 : 0.04),
                radius: isHere ? 14 : 6, y: isHere ? 5 : 2)
        .scaleEffect(isHere ? 1.04 : (arrived ? 1 : 0.94))
        .opacity(arrived ? 1 : 0)
    }

    // MARK: The turn

    /// The first accent on the screen, and it lands on the same beat the
    /// circulation stops — so the colour and the stillness make the point
    /// together, before the sentence has been read.
    private var payoff: some View {
        VStack(alignment: .leading, spacing: VSpace.xs) {
            Text("Nothing in that loop remembers.")
                .font(VType.bodyLarge.weight(.semibold))
                .foregroundStyle(RampStage.accentDeep)

            Text("Every scan is kept, side by side — so the next thing you change is a decision instead of another guess.")
                .font(VType.body)
                .foregroundStyle(RampStage.textSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .opacity(payoffIn ? 1 : 0)
        .offset(y: payoffIn ? 0 : 8)
    }

    // MARK: Choreography

    /// Build it, run it twice, break it.
    ///
    /// Two laps, not one: a single pass reads as a sequence that happens to
    /// end where it began, where the second lap is the moment the reader
    /// realises it is not going to stop on its own. Three would be nagging.
    private func choreograph() async {
        if reduceMotion {
            tilesIn = Self.stops.count
            circuitIn = true
            payoffIn = true
            return
        }

        try? await Task.sleep(for: .milliseconds(200))
        for _ in Self.stops.indices {
            guard !Task.isCancelled else { return }
            Haptics.fire(.tick)
            withAnimation(VMotion.snappy) { tilesIn += 1 }
            try? await Task.sleep(for: .milliseconds(120))
        }

        withAnimation(VMotion.gentle) { circuitIn = true }
        try? await Task.sleep(for: .milliseconds(260))
        guard !Task.isCancelled else { return }

        let laps = 2
        let perLeg = 260
        withAnimation(.linear(duration: Double(laps * 4 * perLeg) / 1000)) {
            spin = Double(laps) * 360
        }
        for _ in 0..<laps {
            for index in Self.stops.indices {
                guard !Task.isCancelled else { return }
                withAnimation(VMotion.snappy) { live = index }
                try? await Task.sleep(for: .milliseconds(UInt64(perLeg)))
            }
        }

        // The stop. Everything settles at once — current off, and the sentence
        // that explains why arrives on the same beat.
        guard !Task.isCancelled else { return }
        Haptics.fire(.milestone)
        withAnimation(VMotion.gentle) {
            live = nil
            payoffIn = true
        }
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
                    Spacer(minLength: RampStage.headerClearance)

                    Text("In 14 days,\nwhat would you notice?")
                        .font(RampStage.serif(26, weight: .semibold))
                        .foregroundStyle(RampStage.ink)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)

                    Text("Your plan is built toward it.")
                        .font(VType.body)
                        .foregroundStyle(RampStage.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.xs)

                    Spacer().frame(height: VSpace.xl)

                    VStack(spacing: RampStage.tileGap) {
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
                    // Fixed, not flexible. Three flexible spacers in one
                    // column share the slack equally, so a `minLength` spacer
                    // here would grow with the others and push the eyebrow
                    // away from the header on a tall canvas.
                    Spacer().frame(height: RampStage.headerClearance)

                    Text("WHAT WE HEARD")
                        .font(VType.micro)
                        .tracking(3)
                        .foregroundStyle(RampStage.accentDeep)
                        .opacity(recapIn ? 1 : 0)
                        .padding(.horizontal, VSpace.lg)

                    // `chips` can legitimately be empty — nothing recognised
                    // on the photo grid and nothing tried — and an empty
                    // bordered card reads as a component that failed to load.
                    if !chips.isEmpty {
                        ledger
                            .padding(.horizontal, VSpace.lg)
                            .padding(.top, VSpace.md)
                    }

                    // The one big break on the screen. Above it is the user's
                    // own testimony; below it is the only thing here they
                    // haven't seen. Two groups, one gap.
                    Spacer(minLength: 30)

                    Text(LocalizedStringKey(headline))
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(RampStage.ink)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(headlineIn ? 1 : 0)
                        .offset(y: headlineIn ? 0 : 12)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.md)

                    reply
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.md)

                    Spacer(minLength: VSpace.lg)

                    RampPrimaryButton(title: "Continue") { onAdvance() }
                        .padding(.horizontal, VSpace.lg)
                        .opacity(buttonIn ? 1 : 0)

                    Spacer().frame(height: VSpace.xxl)
                }
                .frame(minHeight: proxy.size.height, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        // One soft pool of warmth behind the type. The flow's ground is flat
        // white, which is right for the screens made of white cards — but this
        // screen is mostly type, and on bare white that reads as a blank page
        // someone forgot to finish. Scoped to this screen so the tiles
        // elsewhere keep an even ground. Low enough to read as light, never as
        // a coloured shape.
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

    /// What they told us, ticked off one line at a time.
    ///
    /// These answers used to be three 12pt capsules in a caption under a 36pt
    /// headline, at 55% fill so they would not "out-shout" it. That is the
    /// wrong way round for a screen whose entire claim is that we listened:
    /// our sentence was set four times larger than the things we were claiming
    /// to have heard, and the reader's own words arrived as a footnote to it.
    ///
    /// They are now the first thing on the page and the largest thing in the
    /// top half — a ledger of their testimony, each line ticked as it lands,
    /// so the screen demonstrates the listening instead of asserting it. The
    /// headline drops from 36 to 28, which also puts it back on the scale
    /// every other screen in the flow uses.
    private var ledger: some View {
        VStack(spacing: 0) {
            ForEach(chips.indices, id: \.self) { index in
                HStack(spacing: VSpace.md) {
                    ZStack {
                        Circle()
                            .fill(RampStage.accentGradient)
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                    .scaleEffect(index < chipsShown ? 1 : 0.5)

                    Text(LocalizedStringKey(chips[index]))
                        .font(VType.bodyLarge.weight(.semibold))
                        .foregroundStyle(RampStage.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 14)
                .opacity(index < chipsShown ? 1 : 0)
                .offset(x: index < chipsShown ? 0 : -10)

                if index < chips.count - 1 {
                    Rectangle()
                        .fill(RampStage.hair)
                        .frame(height: 1)
                        .opacity(index < chipsShown ? 1 : 0)
                }
            }
        }
        .padding(.horizontal, VSpace.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RampStage.card,
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(RampStage.hair, lineWidth: 1))
        .shadow(color: RampStage.ink.opacity(0.05), radius: 12, y: 4)
        .opacity(recapIn ? 1 : 0)
    }

    /// Our answer, given a home.
    ///
    /// The bottom of this screen was a bare paragraph on white — the ledger
    /// card ended and the page just kept going as running text, which is the
    /// one shape a closing beat cannot afford. It reads as the screen running
    /// out rather than arriving.
    ///
    /// The two cards now make the screen a short conversation: their answers
    /// in white, ours in warm accent, in that order. That is also why the
    /// badge is 💬 and not a decorative flourish — it marks this block as the
    /// reply to the block above it, which is exactly what it is.
    private var reply: some View {
        VStack(alignment: .leading, spacing: VSpace.sm) {
            Text(verbatim: "💬")
                .font(.system(size: 17))
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.white.opacity(0.75)))

            Text(LocalizedStringKey(message))
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(RampStage.ink)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                // Held to a readable measure rather than the full gutter
                // width. Body this size running the whole way across a large
                // phone is a ~60-character line, which is where the eye starts
                // losing its place between rows.
                .frame(maxWidth: 330, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(VSpace.md)
        .background(RampStage.accentSoft,
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .opacity(messageIn ? 1 : 0)
        .offset(y: messageIn ? 0 : 8)
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
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            withAnimation(VMotion.snappy) { chipsShown = i + 1 }
            Haptics.fire(.tick)
        }
        try? await Task.sleep(for: .milliseconds(220))
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
                    Spacer(minLength: RampStage.headerClearance)

                    Text("What have you\nalready tried?")
                        .font(RampStage.serif(26, weight: .semibold))
                        .foregroundStyle(RampStage.ink)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)

                    Text("So we don't hand you the same thing again.")
                        .font(VType.body)
                        .foregroundStyle(RampStage.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.xs)

                    Spacer().frame(height: VSpace.xl)

                    VStack(spacing: RampStage.tileGap) {
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
