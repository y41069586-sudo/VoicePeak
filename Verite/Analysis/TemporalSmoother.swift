import Foundation

/// Exponential moving-average smoother for per-attribute skin estimates.
///
/// Prevents score jumping between scans by blending the latest reading with
/// the historical running average. The alpha parameter controls how quickly
/// the smoother adapts to new values:
///
///   smoothed[t] = α × current + (1 − α) × smoothed[t−1]
///
/// α = 0.25 is deliberately conservative: the smoother takes roughly 4 readings
/// to fully weight a new true signal, which means brief lighting/pose artefacts
/// don't spike the readout, but genuine sustained changes show through within 2–3
/// consecutive scans.
///
/// Actor-isolated so the background `Task.detached` in `SkinAnalysisEngine` can
/// write without data races, and the main thread can read via `async` calls.
actor TemporalSmoother {

    // MARK: Configuration

    /// Blend factor for new readings. Lower = slower / more stable.
    private let alpha: Double

    /// After this many seconds without a new reading the history decays toward
    /// the last reading (avoids stale data staying forever).
    private let decayInterval: TimeInterval

    // MARK: State

    private var history: [SkinAttribute: Double] = [:]
    private var lastUpdateTime: Date = .distantPast

    // MARK: Init

    init(alpha: Double = 0.25, decayInterval: TimeInterval = 120) {
        self.alpha = alpha.clamped01
        self.decayInterval = decayInterval
    }

    // MARK: Public API

    /// Blend `incoming` attributes into the running history and return the
    /// smoothed result. Missing attributes in `incoming` are retained from
    /// history (they don't jump to zero just because one scan skipped them).
    func smooth(attributes: [SkinAttribute: Double]) -> [SkinAttribute: Double] {
        let now = Date()
        applyDecayIfNeeded(at: now)
        lastUpdateTime = now

        for (attr, value) in attributes {
            if let prev = history[attr] {
                history[attr] = alpha * value + (1 - alpha) * prev
            } else {
                history[attr] = value   // cold start: accept as-is
            }
        }
        return history
    }

    /// Return the current smoothed state without updating it (for read-only queries).
    func currentValues() -> [SkinAttribute: Double] { history }

    /// Clear all history — call when a new scan baseline is established.
    func reset() {
        history = [:]
        lastUpdateTime = .distantPast
    }

    // MARK: Private

    /// If too much time has elapsed since the last update, let the history drift
    /// very slowly toward zero so stale readings don't persist forever.
    private func applyDecayIfNeeded(at now: Date) {
        let elapsed = now.timeIntervalSince(lastUpdateTime)
        guard elapsed > decayInterval else { return }
        // Apply a single gentle decay step proportional to elapsed time.
        let decayFactor = max(0, 1.0 - (elapsed / (decayInterval * 4)))
        for attr in history.keys {
            history[attr] = (history[attr] ?? 0) * decayFactor
        }
    }
}

// MARK: - Live-frame smoother (lighter, for RealtimeSkinMonitor)

/// A lightweight synchronous EMA buffer for the live video stream.
/// Not actor-isolated — callers must ensure single-threaded access
/// (the video queue in `CameraController` handles this).
final class LiveSmoother {
    private let alpha: Double
    private var history: [SkinAttribute: Double] = [:]

    init(alpha: Double = 0.18) {
        self.alpha = alpha.clamped01
    }

    func smooth(_ value: Double, for attribute: SkinAttribute) -> Double {
        let prev = history[attribute] ?? value
        let smoothed = alpha * value + (1 - alpha) * prev
        history[attribute] = smoothed
        return smoothed
    }

    func reset() { history = [:] }
}
