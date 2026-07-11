import UIKit
import Security
import Compression

// ============================================================
// MARK: — Live analysis: Perfect Corp YouCam AI (yce.perfectcorp.com)
// ============================================================
//
// S2S pipeline (YCE "AI Skin Analysis", HD concerns):
//   1. POST /client/auth            — id_token = RSA-PKCS1(client_id&timestamp)
//   2. POST /file/skin-analysis     — declare upload → file_id + presigned PUT
//   3. PUT  <presigned url>         — raw JPEG bytes
//   4. POST /task/skin-analysis     — start the task for our 8 HD concerns
//   5. GET  /task/skin-analysis     — poll until success → result URL
//   6. download result (zip of masks + score JSON) → map to DermiqAnalysis
//
// Every failure throws — ScanFlowModel catches and falls back to the mock
// engine, so a network problem can never dead-end the scan theater. Field
// lookups are deliberately defensive (recursive search for hd_* score nodes)
// so minor response-shape changes don't break the mapping.

final class PerfectCorpSkinEngine: DermiqAnalysisEngine {

    private static let base = URL(string: "https://yce-api-01.perfectcorp.com/s2s/v1.0")!

    /// HD concern → our seven categories. `hd_oiliness` rides along solely to
    /// derive the skin type; it maps to no category.
    private static let concernMap: [(action: String, category: DermiqCategory)] = [
        ("hd_texture", .texture),
        ("hd_redness", .redness),
        ("hd_pore", .pores),
        ("hd_age_spot", .evenness),
        ("hd_radiance", .glow),
        ("hd_moisture", .hydration),
        ("hd_acne", .blemishes),
    ]

    func analyze(image: UIImage) async throws -> DermiqAnalysis {
        guard DermiqConfig.hasLiveAnalysis,
              let jpeg = image.jpegData(compressionQuality: 0.85) else {
            throw DermiqEngineError.notConfigured
        }
        let token = try await authenticate()
        let fileID = try await upload(jpeg, token: token)
        let taskID = try await startTask(fileID: fileID, token: token)
        let resultURL = try await pollTask(taskID: taskID, token: token)
        let scores = try await fetchScores(from: resultURL)
        return try Self.buildAnalysis(from: scores)
    }

    // MARK: Step 1 — auth

    private func authenticate() async throws -> String {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let payload = "client_id=\(DermiqSecrets.perfectCorpAPIKey)&timestamp=\(timestamp)"
        guard let idToken = Self.rsaEncrypt(payload,
                                            spkiBase64: DermiqSecrets.perfectCorpRSAPublicKey) else {
            print("[PerfectCorp] RSA key unusable — check PERFECTCORP_RSA_KEY")
            throw DermiqEngineError.notConfigured
        }
        var request = URLRequest(url: Self.base.appendingPathComponent("client/auth"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "client_id": DermiqSecrets.perfectCorpAPIKey,
            "id_token": idToken,
        ])
        let json = try await Self.json(for: request)
        guard let token = (json["result"] as? [String: Any])?["access_token"] as? String else {
            throw DermiqEngineError.badResponse
        }
        return token
    }

    // MARK: Step 2+3 — upload

    private func upload(_ jpeg: Data, token: String) async throws -> String {
        var request = URLRequest(url: Self.base.appendingPathComponent("file/skin-analysis"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "files": [[
                "content_type": "image/jpeg",
                "file_name": "scan.jpg",
                "file_size": jpeg.count,
            ]],
        ])
        let json = try await Self.json(for: request)
        guard let file = ((json["result"] as? [String: Any])?["files"] as? [[String: Any]])?.first,
              let fileID = file["file_id"] as? String,
              let put = (file["requests"] as? [[String: Any]])?.first,
              let putURLString = put["url"] as? String,
              let putURL = URL(string: putURLString) else {
            throw DermiqEngineError.badResponse
        }

        var putRequest = URLRequest(url: putURL)
        putRequest.httpMethod = "PUT"
        if let headers = put["headers"] as? [String: Any] {
            for (key, value) in headers {
                putRequest.setValue("\(value)", forHTTPHeaderField: key)
            }
        }
        let (_, response) = try await URLSession.shared.upload(for: putRequest, from: jpeg)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DermiqEngineError.badResponse
        }
        return fileID
    }

    // MARK: Step 4 — start the task

    private func startTask(fileID: String, token: String) async throws -> String {
        var request = URLRequest(url: Self.base.appendingPathComponent("task/skin-analysis"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "request_id": 0,
            "payload": [
                "file_sets": ["src_ids": [fileID]],
                "actions": [[
                    "id": 0,
                    "params": ["dst_actions": Self.concernMap.map(\.action) + ["hd_oiliness"]],
                ]],
            ],
        ])
        let json = try await Self.json(for: request)
        guard let taskID = (json["result"] as? [String: Any])?["task_id"] as? String else {
            throw DermiqEngineError.badResponse
        }
        return taskID
    }

    // MARK: Step 5 — poll

    private func pollTask(taskID: String, token: String) async throws -> URL {
        var components = URLComponents(
            url: Self.base.appendingPathComponent("task/skin-analysis"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "task_id", value: taskID)]
        guard let url = components?.url else { throw DermiqEngineError.badResponse }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        for _ in 0..<45 {                                   // ≈90 s ceiling
            try await Task.sleep(for: .seconds(2))
            let json = try await Self.json(for: request)
            let result = json["result"] as? [String: Any]
            switch ((result?["status"] as? String) ?? "").lowercased() {
            case "success":
                guard let results = result?["results"] as? [[String: Any]],
                      let data = results.first?["data"] as? [[String: Any]],
                      let urlString = data.first?["url"] as? String,
                      let resultURL = URL(string: urlString) else {
                    throw DermiqEngineError.badResponse
                }
                return resultURL
            case "error", "failed":
                print("[PerfectCorp] task failed: \(result ?? [:])")
                throw DermiqEngineError.badResponse
            default:
                continue                                    // running / pending
            }
        }
        throw DermiqEngineError.badResponse                 // timed out
    }

    // MARK: Step 6 — result → scores

    /// The result URL serves either a bare JSON or a zip (masks + score JSON).
    private func fetchScores(from url: URL) async throws -> [String: Any] {
        let (data, _) = try await URLSession.shared.data(from: url)
        let blobs: [Data]
        if data.starts(with: [0x50, 0x4B]) {                // "PK" — zip
            blobs = MiniZip.entries(in: data)
                .filter { $0.name.lowercased().hasSuffix(".json") }
                .compactMap(\.data)
        } else {
            blobs = [data]
        }
        var merged: [String: Any] = [:]
        for blob in blobs {
            if let object = try? JSONSerialization.jsonObject(with: blob) as? [String: Any] {
                merged.merge(object) { current, _ in current }
            }
        }
        guard !merged.isEmpty else { throw DermiqEngineError.badResponse }
        return merged
    }

    // MARK: Mapping → DermiqAnalysis

    private static func buildAnalysis(from root: [String: Any]) throws -> DermiqAnalysis {
        var found: [String: Int] = [:]
        collectScores(in: root, into: &found)

        let mapped = concernMap.compactMap { pair -> DermiqSubScore? in
            guard let value = found[pair.action] else { return nil }
            return DermiqSubScore(category: pair.category, value: value, trend: nil)
        }
        // Fewer than 5 of 7 concerns ⇒ the contract changed under us. Bail to
        // the mock rather than invent numbers.
        guard mapped.count >= 5 else {
            print("[PerfectCorp] only \(mapped.count)/7 concerns in response — keys: \(found.keys.sorted())")
            throw DermiqEngineError.badResponse
        }
        // Backfill any missing category with the average of the real readings
        // so the grid stays complete (anchored in measured data, not random).
        let average = mapped.map(\.value).reduce(0, +) / mapped.count
        let subScores = concernMap.map { pair in
            DermiqSubScore(category: pair.category,
                           value: found[pair.action] ?? average,
                           trend: nil)
        }

        let overall = found["all"] ?? average
        let weakest = subScores.sorted { $0.value < $1.value }
        let topIssues = weakest.prefix(3).map { DermiqIssue.issue(for: $0.category) }

        return DermiqAnalysis(
            overall: overall,
            subScores: subScores,
            skinType: skinType(oiliness: found["hd_oiliness"], hydration: found["hd_moisture"]),
            topIssues: Array(topIssues),
            honestSummary: HonestSummaryBuilder.summary(overall: overall, weakest: weakest[0])
        )
    }

    /// Walks the whole result tree and records a 0–100 health score for every
    /// node keyed by a concern name (or "all" for the overall).
    private static func collectScores(in node: Any, into out: inout [String: Int], key: String? = nil) {
        let interesting = key.map { $0 == "all" || $0.hasPrefix("hd_") } ?? false
        if let dict = node as? [String: Any] {
            if interesting, let key, let score = healthScore(in: dict) {
                out[key] = score
            }
            for (childKey, value) in dict {
                collectScores(in: value, into: &out, key: childKey)
            }
        } else if let array = node as? [Any] {
            for element in array {
                collectScores(in: element, into: &out, key: key)
            }
        } else if interesting, let key, let number = node as? NSNumber {
            out[key] = clamp(number.doubleValue)
        }
    }

    /// YCE reports `ui_score` (higher = healthier). `raw_score` is severity,
    /// so alone it inverts. `score` is used as-is when it's all we get.
    private static func healthScore(in dict: [String: Any]) -> Int? {
        if let ui = dict["ui_score"] as? NSNumber { return clamp(ui.doubleValue) }
        if let score = dict["score"] as? NSNumber { return clamp(score.doubleValue) }
        if let raw = dict["raw_score"] as? NSNumber { return clamp(100 - raw.doubleValue) }
        return nil
    }

    private static func clamp(_ value: Double) -> Int {
        Int(min(max(value.rounded(), 0), 100))
    }

    private static func skinType(oiliness: Int?, hydration: Int?) -> SkinType {
        guard let oiliness else { return .normal }
        if oiliness < 45 { return .oily }                        // low score = oily
        if oiliness > 75, let hydration, hydration < 50 { return .dry }
        if oiliness < 60 { return .combination }
        return .normal
    }

    // MARK: Shared JSON request

    private static func json(for request: URLRequest) async throws -> [String: Any] {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("[PerfectCorp] HTTP \(code): \(String(data: data.prefix(400), encoding: .utf8) ?? "<binary>")")
            throw DermiqEngineError.badResponse
        }
        return object
    }

    // MARK: RSA (id_token)

    /// Encrypts `payload` with the console-provided RSA public key
    /// (PKCS#1 v1.5), returning base64 — YCE's `id_token` scheme.
    private static func rsaEncrypt(_ payload: String, spkiBase64: String) -> String? {
        let cleaned = spkiBase64.filter { !$0.isWhitespace }
        guard let der = Data(base64Encoded: cleaned) else { return nil }
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
        ]
        // iOS wants PKCS#1 DER; consoles hand out X.509/SPKI. Try as-is first,
        // then with the SPKI header stripped.
        var key = SecKeyCreateWithData(der as CFData, attributes as CFDictionary, nil)
        if key == nil, let pkcs1 = pkcs1Body(fromSPKI: der) {
            key = SecKeyCreateWithData(pkcs1 as CFData, attributes as CFDictionary, nil)
        }
        guard let key,
              SecKeyIsAlgorithmSupported(key, .encrypt, .rsaEncryptionPKCS1),
              let plain = payload.data(using: .utf8),
              let encrypted = SecKeyCreateEncryptedData(key, .rsaEncryptionPKCS1,
                                                        plain as CFData, nil) else {
            return nil
        }
        return (encrypted as Data).base64EncodedString()
    }

    /// X.509 SubjectPublicKeyInfo → inner PKCS#1 RSAPublicKey.
    /// Layout: SEQUENCE { SEQUENCE(AlgorithmIdentifier), BIT STRING { 0x00, body } }
    private static func pkcs1Body(fromSPKI der: Data) -> Data? {
        let bytes = [UInt8](der)
        var index = 0

        func readHeader() -> (tag: UInt8, length: Int)? {
            guard index + 2 <= bytes.count else { return nil }
            let tag = bytes[index]; index += 1
            var length = Int(bytes[index]); index += 1
            if length & 0x80 != 0 {
                let numBytes = length & 0x7F
                guard numBytes > 0, numBytes <= 4, index + numBytes <= bytes.count else { return nil }
                length = 0
                for _ in 0..<numBytes { length = (length << 8) | Int(bytes[index]); index += 1 }
            }
            return (tag, length)
        }

        guard let outer = readHeader(), outer.tag == 0x30 else { return nil }
        guard let algorithm = readHeader(), algorithm.tag == 0x30,
              index + algorithm.length <= bytes.count else { return nil }
        index += algorithm.length
        guard let bitString = readHeader(), bitString.tag == 0x03,
              bitString.length > 1,
              index < bytes.count, bytes[index] == 0x00 else { return nil }
        index += 1
        let end = min(index + bitString.length - 1, bytes.count)
        return Data(bytes[index..<end])
    }
}

// ============================================================
// MARK: — Minimal zip reader
// ============================================================

/// Just enough ZIP to pull the score JSONs out of Perfect Corp's result
/// archive: central-directory walk, stored + deflate entries. No encryption,
/// no zip64 — fine for these small result files.
enum MiniZip {

    struct Entry {
        let name: String
        let data: Data?
    }

    static func entries(in archive: Data) -> [Entry] {
        let bytes = [UInt8](archive)

        // End-of-central-directory record, scanned from the back.
        var eocd = -1
        var cursor = bytes.count - 22
        while cursor >= 0 {
            if bytes[cursor] == 0x50, bytes[cursor + 1] == 0x4B,
               bytes[cursor + 2] == 0x05, bytes[cursor + 3] == 0x06 {
                eocd = cursor
                break
            }
            cursor -= 1
        }
        guard eocd >= 0 else { return [] }

        let entryCount = Int(u16(bytes, eocd + 10))
        var offset = Int(u32(bytes, eocd + 16))
        var result: [Entry] = []

        for _ in 0..<entryCount {
            guard offset + 46 <= bytes.count, u32(bytes, offset) == 0x02014B50 else { break }
            let method = Int(u16(bytes, offset + 10))
            let compressedSize = Int(u32(bytes, offset + 20))
            let uncompressedSize = Int(u32(bytes, offset + 24))
            let nameLength = Int(u16(bytes, offset + 28))
            let extraLength = Int(u16(bytes, offset + 30))
            let commentLength = Int(u16(bytes, offset + 32))
            let localOffset = Int(u32(bytes, offset + 42))
            let name = String(bytes: bytes[(offset + 46)..<(offset + 46 + nameLength)],
                              encoding: .utf8) ?? ""

            // The local header repeats name/extra with possibly different sizes.
            if localOffset + 30 <= bytes.count, u32(bytes, localOffset) == 0x04034B50 {
                let localName = Int(u16(bytes, localOffset + 26))
                let localExtra = Int(u16(bytes, localOffset + 28))
                let start = localOffset + 30 + localName + localExtra
                if start + compressedSize <= bytes.count {
                    let raw = archive.subdata(in: start..<(start + compressedSize))
                    let data: Data?
                    switch method {
                    case 0: data = raw
                    case 8: data = inflate(raw, expectedSize: uncompressedSize)
                    default: data = nil
                    }
                    result.append(Entry(name: name, data: data))
                }
            }
            offset += 46 + nameLength + extraLength + commentLength
        }
        return result
    }

    /// Raw-DEFLATE decompression (zip entries carry no zlib header, which is
    /// exactly what COMPRESSION_ZLIB decodes).
    private static func inflate(_ data: Data, expectedSize: Int) -> Data? {
        guard expectedSize > 0, !data.isEmpty else { return Data() }
        var output = Data(count: expectedSize)
        let written = output.withUnsafeMutableBytes { outBuffer -> Int in
            data.withUnsafeBytes { inBuffer -> Int in
                guard let outPointer = outBuffer.bindMemory(to: UInt8.self).baseAddress,
                      let inPointer = inBuffer.bindMemory(to: UInt8.self).baseAddress else {
                    return 0
                }
                return compression_decode_buffer(outPointer, expectedSize,
                                                 inPointer, data.count,
                                                 nil, COMPRESSION_ZLIB)
            }
        }
        guard written > 0 else { return nil }
        return output.prefix(written)
    }

    private static func u16(_ bytes: [UInt8], _ index: Int) -> UInt16 {
        UInt16(bytes[index]) | (UInt16(bytes[index + 1]) << 8)
    }

    private static func u32(_ bytes: [UInt8], _ index: Int) -> UInt32 {
        UInt32(bytes[index])
            | (UInt32(bytes[index + 1]) << 8)
            | (UInt32(bytes[index + 2]) << 16)
            | (UInt32(bytes[index + 3]) << 24)
    }
}
