import WidgetKit
import SwiftUI

// ============================================================
// MARK: — Vérité routine widget
// ============================================================
//
// A glanceable Home Screen widget: today's routine ring + streak. Reads the
// flat snapshot the app writes into the shared App Group container. The widget
// target compiles only this file and WidgetShared.swift, so it can't see the
// app's design tokens — colors and fonts are defined inline here.

// MARK: Palette (mirrors DQColor, standalone for the extension)

private enum WColor {
    static let accent = Color(red: 0x2E / 255, green: 0x7D / 255, blue: 0xF6 / 255)
    static let accentBright = Color(red: 0x1F / 255, green: 0x6B / 255, blue: 0xE0 / 255)
    static let up = Color(red: 0x2F / 255, green: 0xB8 / 255, blue: 0x7A / 255)
    static let track = Color.primary.opacity(0.08)
    static let secondary = Color.secondary
}

// MARK: Timeline

struct VeriteEntry: TimelineEntry {
    let date: Date
    let snapshot: VeriteWidgetSnapshot
}

struct VeriteProvider: TimelineProvider {
    func placeholder(in context: Context) -> VeriteEntry {
        VeriteEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (VeriteEntry) -> Void) {
        let snap = context.isPreview ? .placeholder : VeriteWidgetStore.read()
        completion(VeriteEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VeriteEntry>) -> Void) {
        let entry = VeriteEntry(date: Date(), snapshot: VeriteWidgetStore.read())
        // The app refreshes us on every routine change; this fallback keeps the
        // day counter honest across midnight even if the app never launches.
        let nextMidnight = Calendar.current.nextDate(
            after: Date(), matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

// MARK: Widget

struct VeriteRoutineWidget: Widget {
    let kind = "VeriteRoutineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VeriteProvider()) { entry in
            VeriteWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Color(.systemBackground) }
        }
        .configurationDisplayName("Routine")
        .description("Your 14-day plan at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: Views

struct VeriteWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: VeriteWidgetSnapshot

    var body: some View {
        if !snapshot.hasPlan {
            emptyState
        } else if family == .systemMedium {
            mediumBody
        } else {
            smallBody
        }
    }

    // Small: the ring, front and centre.
    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 6)
            HStack {
                Spacer()
                ring(size: 74, line: 9)
                Spacer()
            }
            Spacer(minLength: 6)
            footline
        }
    }

    // Medium: ring on the left, the day + step read-out on the right.
    private var mediumBody: some View {
        HStack(spacing: 18) {
            ring(size: 92, line: 11)
            VStack(alignment: .leading, spacing: 8) {
                header
                Spacer(minLength: 0)
                Text(snapshot.allDoneToday
                     ? "Today complete — see you tomorrow."
                     : "\(snapshot.doneToday) of \(snapshot.totalToday) steps today")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(snapshot.allDoneToday ? WColor.up : WColor.secondary)
                    .lineLimit(2)
                footline
            }
            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("Day \(snapshot.day)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
            Text("of \(snapshot.totalDays)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(WColor.secondary)
            Spacer(minLength: 0)
        }
    }

    private var footline: some View {
        HStack(spacing: 4) {
            if snapshot.streak > 0 {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(WColor.up)
                Text("\(snapshot.streak)")
                    .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(WColor.up)
            }
            Spacer(minLength: 0)
            Text("Vérité")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(WColor.accent.opacity(0.85))
        }
    }

    private func ring(size: CGFloat, line: CGFloat) -> some View {
        ZStack {
            Circle().stroke(WColor.track, lineWidth: line)
            Circle()
                .trim(from: 0, to: max(0.001, snapshot.fractionToday))
                .stroke(
                    LinearGradient(
                        colors: snapshot.allDoneToday
                            ? [WColor.up, WColor.up]
                            : [WColor.accent, WColor.accentBright],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if snapshot.allDoneToday {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(WColor.up)
            } else {
                VStack(spacing: 0) {
                    Text("\(snapshot.doneToday)")
                        .font(.system(size: size * 0.34, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(.primary)
                    Text("/ \(snapshot.totalToday)")
                        .font(.system(size: size * 0.16, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(WColor.secondary)
                }
            }
        }
        .frame(width: size, height: size)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(WColor.accent)
            Text("Start your\n14-day plan")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
            Text("Vérité")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(WColor.accent.opacity(0.85))
        }
    }
}
