import Foundation

/// Parses a raw INCI ingredient string (as it appears on a label / from Open
/// Beauty Facts) into a clean, de-duplicated, ordered list of ingredient names.
enum INCIParser {

    static func parse(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }

        var body = text
        // Drop a leading "Ingredients:" / "Ingredienti:" style label.
        if let colon = body.firstIndex(of: ":"),
           body.distance(from: body.startIndex, to: colon) < 16 {
            body = String(body[body.index(after: colon)...])
        }

        let separators = CharacterSet(charactersIn: ",;\n•·|")
        let trimSet = CharacterSet(charactersIn: ".*()[]{}:").union(.whitespacesAndNewlines)

        var result: [String] = []
        var seen = Set<String>()
        for rawToken in body.components(separatedBy: separators) {
            let name = rawToken.trimmingCharacters(in: trimSet)
            guard name.count >= 2 else { continue }

            let lower = name.lowercased()
            // Skip label noise like "may contain" / "+/-" colorant sections.
            if lower.hasPrefix("may contain") || lower.hasPrefix("+/-") || lower.hasPrefix("+/") { continue }

            if seen.insert(lower).inserted {
                result.append(name)
            }
            if result.count >= 60 { break } // labels beyond this are noise for v1
        }
        return result
    }

    /// Normalized key for knowledge-base lookup.
    static func normalize(_ name: String) -> String {
        name.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ".", with: "")
    }
}
