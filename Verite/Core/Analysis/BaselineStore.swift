import Foundation

/// Manages baseline scan storage and comparison logic.
/// Baseline is the first scan; subsequent scans are compared against it.
actor BaselineStore: Sendable {
    private var baseline: ScanAnalysisResult?
    private let fileURL: URL
    
    init(storageDirectory: URL = FileManager.default.documentDirectory) {
        self.fileURL = storageDirectory.appendingPathComponent("baseline_scan.json")
    }
    
    // MARK: - Public API
    
    /// Check if a baseline exists.
    func hasBaseline() -> Bool {
        baseline != nil || FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// Get the stored baseline scan.
    func getBaseline() -> ScanAnalysisResult? {
        if let baseline = baseline {
            return baseline
        }
        
        // Try loading from disk
        let loaded = loadBaseline()
        if let loaded = loaded {
            baseline = loaded
        }
        return loaded
    }
    
    /// Store a scan as the baseline.
    /// This overwrites any existing baseline.
    func setBaseline(_ scan: ScanAnalysisResult) throws {
        self.baseline = scan
        try save(scan, to: fileURL)
    }
    
    /// Clear the stored baseline.
    func clearBaseline() throws {
        self.baseline = nil
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    /// Compare a scan to the baseline and return deltas.
    func compareToBaseline(_ scan: ScanAnalysisResult) -> BaselineComparison? {
        guard let baseline = getBaseline() else {
            return nil
        }
        
        let deltas = AttributeDeltas(
            rednes: scan.rednesScore.value - baseline.rednesScore.value,
            acne: scan.acneScore.value - baseline.acneScore.value,
            oiliness: scan.oilinessScore.value - baseline.oilinessScore.value,
            texture: scan.textureScore.value - baseline.textureScore.value,
            pore: scan.poreScore.value - baseline.poreScore.value,
            hydration: scan.hydrationScore.value - baseline.hydrationScore.value,
            sensitivity: scan.sensitivityScore.value - baseline.sensitivityScore.value
        )
        
        let trend = determineTrend(deltas)
        
        return BaselineComparison(
            baselineId: baseline.id,
            baselineTimestamp: baseline.timestamp,
            deltas: deltas,
            trend: trend
        )
    }
    
    // MARK: - Private
    
    private func loadBaseline() -> ScanAnalysisResult? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(ScanAnalysisResult.self, from: data)
        } catch {
            print("Failed to load baseline: \(error)")
            return nil
        }
    }
    
    private func save(_ scan: ScanAnalysisResult, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(scan)
        try data.write(to: url, options: .atomic)
    }
    
    private func determineTrend(_ deltas: AttributeDeltas) -> SkinTrend {
        let changes = [
            deltas.rednes,
            deltas.acne,
            deltas.oiliness,
            deltas.texture,
            deltas.pore,
            deltas.sensitivity
        ]
        
        let avgChange = changes.reduce(0, +) / Float(changes.count)
        
        // Threshold: ±2% is considered stable
        if abs(avgChange) <= 2.0 {
            return .stable
        }
        
        return avgChange > 0 ? .worsening : .improving
    }
}

// MARK: - FileManager Extension

extension FileManager {
    var documentDirectory: URL {
        urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
