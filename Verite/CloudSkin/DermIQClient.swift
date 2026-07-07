import Foundation
import UIKit

/// One cloud-analyzed skin result, mapped to what the UI needs today. The
/// per-attribute breakdown DermIQ returns in `result_json` isn't in the
/// published OpenAPI schema, so it's kept as `raw` — read concrete keys out
/// once a real response confirms them (see README.md).
struct CloudSkinAnalysis: Sendable {
    let overallScore: Double?
    let skinAge: Int?
    /// Concern name → mask image, fetched from `/v1/results/{id}/masks/{name}`.
    let masks: [String: UIImage]
    let raw: DermIQJSONValue?
}

enum CloudSkinAnalysisError: Error {
    case notConfigured, badURL, http(Int), analysisFailed, timedOut
}

/// Optional cloud skin analysis. Sends the captured face photo to DermIQ —
/// the one path in the app where a face photo leaves the device — so it's off
/// unless `FeatureFlags.cloudSkinAnalysisEnabled` is explicitly on *and*
/// `DermIQConfig` is present. See README.md for setup and the privacy note.
protocol CloudSkinAnalysisService: Sendable {
    var isEnabled: Bool { get }
    func analyze(image: UIImage, quick: Bool) async throws -> CloudSkinAnalysis
}

struct DisabledCloudSkinAnalysis: CloudSkinAnalysisService {
    var isEnabled: Bool { false }
    func analyze(image: UIImage, quick: Bool) async throws -> CloudSkinAnalysis {
        throw CloudSkinAnalysisError.notConfigured
    }
}

/// Talks to the DermIQ API: `POST /v1/analyze[/quick]` (submit) →
/// `GET /v1/results/{id}` (poll until done) → `GET /v1/results/{id}/masks/{name}`
/// (fetch each heatmap overlay). `quick: true` is the cheaper/faster mode —
/// intended for a live preview; `quick: false` ("full") for a saved scan.
struct DermIQClient: CloudSkinAnalysisService {
    let config: DermIQConfig

    var isEnabled: Bool { config.isConfigured }

    func analyze(image: UIImage, quick: Bool) async throws -> CloudSkinAnalysis {
        guard isEnabled else { throw CloudSkinAnalysisError.notConfigured }
        guard let jpeg = image.jpegData(compressionQuality: 0.9) else { throw CloudSkinAnalysisError.badURL }

        let submitted = try await submit(jpeg: jpeg, quick: quick)
        let result = try await pollResult(id: submitted.analysisID)

        var masks: [String: UIImage] = [:]
        for name in result.maskFilenames ?? [] {
            if let data = try? await maskData(analysisID: result.id, maskName: name),
               let maskImage = UIImage(data: data) {
                masks[name] = maskImage
            }
        }

        return CloudSkinAnalysis(
            overallScore: result.overallScore,
            skinAge: result.skinAge,
            masks: masks,
            raw: result.resultJSON
        )
    }

    // MARK: Submit

    private func submit(jpeg: Data, quick: Bool) async throws -> DermIQAnalyzeResponse {
        let path = quick ? "/v1/analyze/quick" : "/v1/analyze"
        guard let url = URL(string: path, relativeTo: config.baseURL) else { throw CloudSkinAnalysisError.badURL }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = Self.multipartBody(boundary: boundary, fileField: "file",
                                              filename: "scan.jpg", mimeType: "image/jpeg", fileData: jpeg)

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.checkStatus(response)
        return try JSONDecoder().decode(DermIQAnalyzeResponse.self, from: data)
    }

    // MARK: Poll

    /// Polls every 1.5s for up to ~30s — DermIQ's analyze endpoints are async
    /// (submit → poll); no webhook/push path is wired for this client.
    private func pollResult(id: String) async throws -> DermIQAnalysisResult {
        guard let url = URL(string: "/v1/results/\(id)", relativeTo: config.baseURL) else {
            throw CloudSkinAnalysisError.badURL
        }
        for _ in 0..<20 {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            try Self.checkStatus(response)
            let result = try JSONDecoder().decode(DermIQAnalysisResult.self, from: data)
            if result.isFailure { throw CloudSkinAnalysisError.analysisFailed }
            if result.isTerminal { return result }
            try? await Task.sleep(for: .seconds(1.5))
        }
        throw CloudSkinAnalysisError.timedOut
    }

    // MARK: Masks

    private func maskData(analysisID: String, maskName: String) async throws -> Data {
        guard let url = URL(string: "/v1/results/\(analysisID)/masks/\(maskName)", relativeTo: config.baseURL) else {
            throw CloudSkinAnalysisError.badURL
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.checkStatus(response)
        return data
    }

    // MARK: Helpers

    private static func multipartBody(boundary: String, fileField: String, filename: String,
                                      mimeType: String, fileData: Data) -> Data {
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(filename)\"\r\n"
            .data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }

    private static func checkStatus(_ response: URLResponse) throws {
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw CloudSkinAnalysisError.http(http.statusCode)
        }
    }
}
