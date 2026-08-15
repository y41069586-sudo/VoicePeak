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
