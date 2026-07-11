import WidgetKit
import SwiftUI

// The widget extension's entry point. One widget for now — the routine tracker.
@main
struct VeriteWidgetBundle: WidgetBundle {
    var body: some Widget {
        VeriteRoutineWidget()
    }
}
