import UIKit
import Security
import Compression

// ============================================================
// MARK: — Live analysis: Perfect Corp YouCam AI (yce.perfectcorp.com)
// ============================================================
//
// S2S pipeline (YCE "AI Skin Analysis", HD concerns), per the confirmed
// contract from Perfect Corp's own SDK samples:
//   1. POST v1.0/client/auth          — id_token = base64(RSA-PKCS1v1.5(
//                                       "client_id=<key>&timestamp=<ms>", pubkey))
//   2. POST v2.0/file/skin-analysis   — declare upload → file_id + presigned PUT
//   3. PUT  <presigned url>           — raw JPEG bytes
//   4. POST v2.0/task/skin-analysis   — {src_file_id, dst_actions:[7 hd_*], format:"json"}
//   5. GET  v2.0/task/skin-analysis/<id> — poll until success
//   6. read results.output[].ui_score → map to DermiqAnalysis
//
// Every failure throws — ScanFlowModel catches and falls back to the mock
// engine, so a network problem can never dead-end the scan theater.

final class PerfectCorpSkinEngine: DermiqAnalysisEngine {

    // Auth is on the v1.0 path; the file + task data-plane is v2.x.
    private static let authBase = URL(string: "https://yce-api-01.perfectcorp.com/s2s/v1.0")!
    private static let dataBase = URL(string: "https://yce-api-01.perfectcorp.com/s2s/v2.0")!

    /// Our seven categories ↔ Perfect Corp HD concerns. `hd` is what we request
    /// (`dst_actions`); `base` is the `type` string the response comes back
    /// with (HD prefix sometimes stripped). Exactly seven — a valid action
    /// count (the API rejects counts other than 4 / 7 / 14).
    private static let concernMap: [(hd: String, base: String, category: DermiqCategory)] = [
        ("hd_texture",  "texture",  .texture),
        ("hd_redness",  "redness",  .redness),
        ("hd_pore",     "pore",     .pores),
        ("hd_age_spot", "age_spot", .evenness),
        ("hd_radiance", "radiance", .glow),
        ("hd_moisture", "moisture", .hydration),
        ("hd_acne",     "acne",     .blemishes),
    ]

    private static let categoryForBase: [String: DermiqCategory] =
        Dictionary(uniqueKeysWithValues: concernMap.map { ($0.base, $0.category) })

    func analyze(image: UIImage) async throws -> DermiqAnalysis {
        guard DermiqConfig.hasLiveAnalysis,
              let jpeg = image.jpegData(compressionQuality: 0.85) else {
            DermiqDiagnostics.record("Mock — no API keys in this build")
            throw DermiqEngineError.notConfigured
        }
        let token = try await authenticate()
        let fileID = try await upload(jpeg, token: token)
        let taskID = try await startTask(fileID: fileID, token: token)
        let results = try await pollTask(taskID: taskID, token: token)
        let analysis = try Self.buildAnalysis(from: results)
        DermiqDiagnostics.record("Perfect Corp LIVE ✓ — overall \(analysis.overall)")
        return analysis
    }

    // MARK: Step 1 — auth
    // id_token = base64( RSA-PKCS1v1.5-encrypt( "client_id=<key>&timestamp=<ms>",
    // console public "Secret key" ) ), POSTed with the plaintext client_id.

    private func authenticate() async throws -> String {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let payload = "client_id=\(DermiqSecrets.perfectCorpAPIKey)&timestamp=\(timestamp)"
        guard let idToken = Self.rsaEncrypt(payload,
                                            spkiBase64: DermiqSecrets.perfectCorpRSAPublicKey) else {
            print("[PerfectCorp] RSA key unusable — check PERFECTCORP_RSA_KEY")
            DermiqDiagnostics.record("RSA key unusable (PERFECTCORP_RSA_KEY missing/bad)")
            throw DermiqEngineError.notConfigured
        }
        var request = URLRequest(url: Self.authBase.appendingPathComponent("client/auth"))
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

    // MARK: Step 2+3 — declare file, then PUT the bytes to the presigned URL

    private func upload(_ jpeg: Data, token: String) async throws -> String {
        var request = URLRequest(url: Self.dataBase.appendingPathComponent("file/skin-analysis"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let fileEntry: [String: Any] = [
            "content_type": "image/jpeg",
            "file_name": "scan.jpg",
            "file_size": jpeg.count,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: ["files": [fileEntry]])
        let json = try await Self.json(for: request)
        // v2.0 wraps the payload in "data"; older versions use "result".
        guard let file = (Self.container(json)["files"] as? [[String: Any]])?.first,
              let fileID = file["file_id"] as? String,
              let put = (file["requests"] as? [[String: Any]])?.first,
              let putURLString = put["url"] as? String,
              let putURL = URL(string: putURLString) else {
            throw DermiqEngineError.badResponse
        }

        var putRequest = URLRequest(url: putURL)
        putRequest.httpMethod = (put["method"] as? String) ?? "PUT"
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

    // MARK: Step 4 — start the task (v2.x flat form)

    private func startTask(fileID: String, token: String) async throws -> String {
        var request = URLRequest(url: Self.dataBase.appendingPathComponent("task/skin-analysis"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "src_file_id": fileID,
            "dst_actions": Self.concernMap.map { $0.hd },
            "format": "json",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let json = try await Self.json(for: request)
        guard let taskID = (Self.container(json)["task_id"] as? String)
                ?? (json["task_id"] as? String) else {
            throw DermiqEngineError.badResponse
        }
        return taskID
    }

    /// v2.0 responses wrap the payload in "data"; older ones use "result".
    private static func container(_ json: [String: Any]) -> [String: Any] {
        (json["result"] as? [String: Any]) ?? (json["data"] as? [String: Any]) ?? json
    }

    // MARK: Step 5 — poll until done, return the `results` object

    private func pollTask(taskID: String, token: String) async throws -> [String: Any] {
        let url = Self.dataBase
            .appendingPathComponent("task/skin-analysis")
            .appendingPathComponent(taskID)
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        for _ in 0..<45 {                                   // ≈90 s ceiling
            try await Task.sleep(for: .seconds(2))
            let json = try await Self.json(for: request)
            let container = (json["result"] as? [String: Any]) ?? (json["data"] as? [String: Any]) ?? json
            let status = ((container["status"] as? String)
                          ?? (container["task_status"] as? String) ?? "").lowercased()

            switch status {
            case "success", "done", "completed":
                // v2 + format:json → results inline; older → a URL to a zip.
                if let results = container["results"] as? [String: Any], results["output"] != nil {
                    return results
                }
                if let url = Self.resultURL(in: container) {
                    return try await Self.downloadResults(from: url)
                }
                // Some shapes put the output array directly under results.
                if let results = container["results"] as? [String: Any] { return results }
                throw DermiqEngineError.badResponse
            case "error", "failed", "fail":
                let reason = (container["error"] as? String) ?? "unknown"
                print("[PerfectCorp] task failed: \(container)")
                DermiqDiagnostics.record("Task error: \(reason)")
                throw DermiqEngineError.badResponse
            default:
                continue                                    // running / pending
            }
        }
        DermiqDiagnostics.record("Task timed out (still running after 90 s)")
        throw DermiqEngineError.badResponse                 // timed out
    }

    /// Finds a result download URL in any of the shapes seen in the wild.
    private static func resultURL(in container: [String: Any]) -> URL? {
        if let s = container["url"] as? String, let u = URL(string: s) { return u }
        if let results = container["results"] as? [[String: Any]],
           let data = results.first?["data"] as? [[String: Any]],
           let s = data.first?["url"] as? String, let u = URL(string: s) { return u }
        return nil
    }

    /// Download + parse the result payload (bare JSON or a zip of JSON+masks).
    private static func downloadResults(from url: URL) async throws -> [String: Any] {
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

    /// Accepts the `results` object in either shape:
    ///  • v2 JSON: `{ output: [{type, ui_score|whole.ui_score}], all:{score}, skin_age }`
    ///  • zip `score_info.json`: `{ texture:{ui_score}, pore:{ui_score}, … }`
    private static func buildAnalysis(from results: [String: Any]) throws -> DermiqAnalysis {
        var byCategory: [DermiqCategory: Int] = [:]
        var overallFromAll: Int?

        if let output = results["output"] as? [[String: Any]] {
            for item in output {
                guard let type = item["type"] as? String else { continue }
                // Some metrics come split by region (pore: forehead/nose/cheek
                // /whole). Keep only the "whole" aggregate or region-less rows.
                if let region = item["region"] as? String, region != "whole" { continue }
                // The overall lives in the output array as type "all".
                if type == "all" { overallFromAll = score(in: item); continue }
                let base = type.hasPrefix("hd_") ? String(type.dropFirst(3)) : type
                guard let category = categoryForBase[base],
                      let sc = score(in: item) else { continue }
                byCategory[category] = sc
            }
        } else {
            // Flat metric-keyed dict (zip / older shapes).
            for (hd, base, category) in concernMap {
                if let node = (results[base] ?? results[hd]),
                   let sc = score(in: node) {
                    byCategory[category] = sc
                }
            }
        }

        // Fewer than 5 of 7 ⇒ the contract shifted; bail to the mock rather
        // than invent numbers.
        guard byCategory.count >= 5 else {
            print("[PerfectCorp] only \(byCategory.count)/7 concerns parsed — results keys: \(results.keys.sorted())")
            throw DermiqEngineError.badResponse
        }

        let average = byCategory.values.reduce(0, +) / byCategory.count
        let subScores = DermiqCategory.allCases.map {
            DermiqSubScore(category: $0, value: byCategory[$0] ?? average, trend: nil)
        }

        let overall = overallFromAll ?? overallScore(in: results) ?? average
        let weakest = subScores.sorted { $0.value < $1.value }
        let topIssues = weakest.prefix(3).map { DermiqIssue.issue(for: $0.category) }

        return DermiqAnalysis(
            overall: overall,
            subScores: subScores,
            skinType: skinType(hydration: byCategory[.hydration], redness: byCategory[.redness]),
            topIssues: Array(topIssues),
            honestSummary: HonestSummaryBuilder.summary(overall: overall, weakest: weakest[0])
        )
    }

    /// A 0–100 health score from a metric node. Prefer `ui_score`; for
    /// region-split metrics use the `.whole`/`.all` sub-node; fall back to a
    /// bare `score`, then invert a severity `raw_score`.
    private static func score(in node: Any) -> Int? {
        guard let dict = node as? [String: Any] else {
            if let n = node as? NSNumber { return clamp(n.doubleValue) }
            return nil
        }
        if let ui = dict["ui_score"] as? NSNumber { return clamp(ui.doubleValue) }
        for region in ["whole", "all", "overall"] {
            if let sub = dict[region] as? [String: Any],
               let ui = sub["ui_score"] as? NSNumber { return clamp(ui.doubleValue) }
        }
        if let s = dict["score"] as? NSNumber { return clamp(s.doubleValue) }
        if let raw = dict["raw_score"] as? NSNumber {
            let v = raw.doubleValue
            return clamp(v <= 1 ? (1 - v) * 100 : 100 - v)  // severity → health
        }
        return nil
    }

    private static func overallScore(in results: [String: Any]) -> Int? {
        if let all = results["all"] as? [String: Any] { return score(in: all) }
        if let n = results["all"] as? NSNumber { return clamp(n.doubleValue) }
        return nil
    }

    private static func clamp(_ value: Double) -> Int {
        Int(min(max(value.rounded(), 0), 100))
    }

    /// Rough skin type from the two metrics we have (no dedicated oiliness in
    /// the requested set): low hydration → dry, high redness → sensitive.
    private static func skinType(hydration: Int?, redness: Int?) -> SkinType {
        if let hydration, hydration < 45 { return .dry }
        if let redness, redness < 45 { return .sensitive }
        return .combination
    }

    // MARK: Shared JSON request

    private static func json(for request: URLRequest) async throws -> [String: Any] {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data.prefix(200), encoding: .utf8) ?? "<binary>"
            print("[PerfectCorp] HTTP \(code): \(body)")
            DermiqDiagnostics.record("HTTP \(code): \(body)")
            throw DermiqEngineError.badResponse
        }
        return object
    }

    // MARK: RSA (id_token)

    /// Encrypts `payload` with the console-provided RSA public key
    /// (PKCS#1 v1.5), returning base64 — YCE's `id_token` scheme.
    private static func rsaEncrypt(_ payload: String, spkiBase64: String) -> String? {
        // Accept the bare console value OR one accidentally pasted with PEM
        // header lines; keep only the base64 body.
        var cleaned = spkiBase64
        for header in ["-----BEGIN PUBLIC KEY-----", "-----END PUBLIC KEY-----",
                       "-----BEGIN RSA PUBLIC KEY-----", "-----END RSA PUBLIC KEY-----"] {
            cleaned = cleaned.replacingOccurrences(of: header, with: "")
        }
        cleaned = cleaned.filter { !$0.isWhitespace }
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
            // A truncated/malformed entry must not trap the slice below.
            guard offset + 46 + nameLength + extraLength + commentLength <= bytes.count else { break }
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
