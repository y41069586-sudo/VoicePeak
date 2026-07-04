import Foundation

extension Collection where Element: AdditiveArithmetic {
    /// Calculate the average of numeric elements.
    var average: Element {
        let sum = reduce(.zero, +)
        return isEmpty ? .zero : sum
    }
}

extension Collection where Element == Double {
    /// Calculate the average of Double values.
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
