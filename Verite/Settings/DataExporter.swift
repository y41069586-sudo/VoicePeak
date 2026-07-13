import SwiftData
import Foundation

/// Exports the user's on-device data as JSON — numeric metrics + routine only.
/// **Face photos are never included** (they never leave the device).
@MainActor
enum DataExporter {

    struct Bundle: Codable {
        let exportedAt: Date
        let note: String
        var profile: ProfileExport?
        var scans: [ScanExport]
        var tests: [TestExport]
        var routine: [RoutineExport]
        var savings: SavingsExport?
    }

    struct ProfileExport: Codable {
        let skinType: String?
        let concerns: [String]
        let sensitivities: [String]
        let currentProducts: [String]
        let goal: String?
        let createdAt: Date
    }
    struct ScanExport: Codable {
        let date: Date
        let side: String
        let isBaseline: Bool
        let captureQuality: Double
        let attributes: [String: Double]
    }
    struct TestExport: Codable {
        let startDate: Date
        let status: String
        let cadenceDays: Int
        let confidence: Double
    }
    struct RoutineExport: Codable {
        let timeOfDay: String
        let order: Int
        let proven: Bool
    }
    struct SavingsExport: Codable {
        let totalSaved: Double
        let currencyCode: String
        let failedTestsCount: Int
    }

    static func exportURL(context: ModelContext) -> URL? {
        let profile = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first
        let scans = (try? context.fetch(FetchDescriptor<Scan>())) ?? []
        let tests = (try? context.fetch(FetchDescriptor<HalfFaceTest>())) ?? []
        let routine = (try? context.fetch(FetchDescriptor<RoutineItem>())) ?? []
        let savings = (try? context.fetch(FetchDescriptor<SavingsLedger>()))?.first

        let bundle = Bundle(
            exportedAt: .now,
            note: "SKINMAXX data export — numeric metrics and routine only. Face photos are never included.",
            profile: profile.map {
                ProfileExport(skinType: $0.skinType?.rawValue,
                              concerns: $0.concerns.map(\.rawValue),
                              sensitivities: $0.sensitivities,
                              currentProducts: $0.currentProducts,
                              goal: $0.goal,
                              createdAt: $0.createdAt)
            },
            scans: scans.map {
                ScanExport(date: $0.date, side: $0.side.rawValue, isBaseline: $0.isBaseline,
                           captureQuality: $0.captureQuality, attributes: $0.attributeScores)
            },
            tests: tests.map {
                TestExport(startDate: $0.startDate, status: $0.status.rawValue,
                           cadenceDays: $0.cadenceDays, confidence: $0.confidence)
            },
            routine: routine.map {
                RoutineExport(timeOfDay: $0.timeOfDay.rawValue, order: $0.order, proven: $0.proven)
            },
            savings: savings.map {
                SavingsExport(totalSaved: $0.totalSaved, currencyCode: $0.currencyCode,
                              failedTestsCount: $0.failedTestsCount)
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(bundle) else { return nil }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("verite-export.json")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
