import Foundation
import SwiftUI

/// Defines gamification tasks the user can complete for flames (points).
enum FlameTask: String, CaseIterable, Identifiable {
    case dailyScan
    case completeAMRoutine
    case completePMRoutine
    case finishHalfFaceTest
    case shareResult
    
    var id: String { rawValue }
    
    var titleKey: LocalizedStringKey {
        switch self {
        case .dailyScan: return "task.dailyScan.title"
        case .completeAMRoutine: return "task.amRoutine.title"
        case .completePMRoutine: return "task.pmRoutine.title"
        case .finishHalfFaceTest: return "task.halfFaceTest.title"
        case .shareResult: return "task.shareResult.title"
        }
    }
    
    var defaultTitle: String {
        switch self {
        case .dailyScan: return "Täglicher Scan"
        case .completeAMRoutine: return "Morgen-Routine abschließen"
        case .completePMRoutine: return "Abend-Routine abschließen"
        case .finishHalfFaceTest: return "Half-Face Test durchführen"
        case .shareResult: return "Ergebnis teilen"
        }
    }
    
    var reward: Int {
        switch self {
        case .dailyScan: return 5
        case .completeAMRoutine: return 10
        case .completePMRoutine: return 10
        case .finishHalfFaceTest: return 50
        case .shareResult: return 20
        }
    }
    
    var icon: String {
        switch self {
        case .dailyScan: return "camera.viewfinder"
        case .completeAMRoutine: return "sun.max"
        case .completePMRoutine: return "moon.stars"
        case .finishHalfFaceTest: return "flask"
        case .shareResult: return "square.and.arrow.up"
        }
    }
}
