import Foundation

/// A generic JSON value — used to decode DermIQ's `result_json`, whose exact
/// per-metric keys aren't declared in the OpenAPI schema (typed there as a bare
/// `object`). Read concrete keys out via the subscript/accessors below once a
/// real response confirms them; this keeps decoding safe against any shape the
/// API actually returns.
enum DermIQJSONValue: Decodable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: DermIQJSONValue])
    case array([DermIQJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let v = try? container.decode(Bool.self) { self = .bool(v); return }
        if let v = try? container.decode(Double.self) { self = .number(v); return }
        if let v = try? container.decode(String.self) { self = .string(v); return }
        if let v = try? container.decode([String: DermIQJSONValue].self) { self = .object(v); return }
        if let v = try? container.decode([DermIQJSONValue].self) { self = .array(v); return }
        self = .null
    }

    subscript(key: String) -> DermIQJSONValue? {
        guard case .object(let dict) = self else { return nil }
        return dict[key]
    }
    var doubleValue: Double? { if case .number(let d) = self { return d }; return nil }
    var stringValue: String? { if case .string(let s) = self { return s }; return nil }
}

/// `POST /v1/analyze` (or `/v1/analyze/quick`) response — the job has been
/// accepted; poll `GET /v1/results/{analysis_id}` for the finished analysis.
struct DermIQAnalyzeResponse: Decodable, Sendable {
    let analysisID: String
    let status: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case analysisID = "analysis_id"
        case status, message
    }
}

/// `GET /v1/results/{analysis_id}` — the full analysis record.
///
/// `status` and `analysisType` are decoded as raw strings, not a strict enum:
/// the OpenAPI schema declares both as enums but doesn't expose the exact
/// member spelling, so hardcoding guessed cases here could silently break
/// polling if the API uses different casing/wording. `isTerminal`/`isFailure`
/// drive polling off signals that don't depend on exact enum spelling —
/// tighten these once one real response confirms the actual status strings.
struct DermIQAnalysisResult: Decodable, Sendable {
    let id: String
    let status: String
    let analysisType: String
    let resultJSON: DermIQJSONValue?
    let maskFilenames: [String]?
    let overallScore: Double?
    let skinAge: Int?
    let processingTimeMs: Int?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, status
        case analysisType = "analysis_type"
        case resultJSON = "result_json"
        case maskFilenames = "mask_filenames"
        case overallScore = "overall_score"
        case skinAge = "skin_age"
        case processingTimeMs = "processing_time_ms"
        case createdAt = "created_at"
    }

    /// True once the job has produced output or failed — checked by content
    /// (a result actually arrived) first, falling back to loose substring
    /// matching on `status` for cases with no score yet.
    var isTerminal: Bool {
        if resultJSON != nil || overallScore != nil { return true }
        let s = status.lowercased()
        return s.contains("complet") || s.contains("done") || s.contains("fail") || s.contains("error")
    }

    var isFailure: Bool {
        let s = status.lowercased()
        return (resultJSON == nil && overallScore == nil) && (s.contains("fail") || s.contains("error"))
    }
}
