import Foundation

enum CalculationOperation: String, CaseIterable, Codable, Identifiable {
    case addition, subtraction, multiplication, division

    static let defaultValue = Self.multiplication
    var id: String { rawValue }
    var title: String {
        switch self {
        case .addition: return "Add"
        case .subtraction: return "Subtract"
        case .multiplication: return "Multiply"
        case .division: return "Divide"
        }
    }
    var symbol: String {
        switch self {
        case .addition: return "+"
        case .subtraction: return "−"
        case .multiplication: return "×"
        case .division: return "÷"
        }
    }
    var spokenSymbol: String {
        switch self {
        case .addition: return "plus"
        case .subtraction: return "minus"
        case .multiplication: return "times"
        case .division: return "divided by"
        }
    }
    var systemImage: String {
        switch self {
        case .addition: return "plus"
        case .subtraction: return "minus"
        case .multiplication: return "multiply"
        case .division: return "divide"
        }
    }
    var ordersLargestFirst: Bool { self == .subtraction || self == .division }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: value) ?? .defaultValue
    }
}

enum CalculationDigits: Int, CaseIterable, Codable, Identifiable {
    case two = 2, three = 3

    var id: Int { rawValue }
    var title: String { "\(rawValue) digits" }
    var range: ClosedRange<Int> { self == .two ? 10...99 : 100...999 }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(Int.self)
        self = Self(rawValue: value) ?? .two
    }
}

struct CalculationSettings: Equatable {
    var firstDigits: CalculationDigits = .two
    var secondDigits: CalculationDigits = .two
    var operation: CalculationOperation = .defaultValue

    static let defaultValue = Self()

    // For subtraction and division, the two size choices describe a pair, not a fixed order.
    var orderedDigits: (CalculationDigits, CalculationDigits) {
        if operation.ordersLargestFirst && firstDigits.rawValue < secondDigits.rawValue {
            return (secondDigits, firstDigits)
        }
        return (firstDigits, secondDigits)
    }

    var summary: String {
        let (first, second) = orderedDigits
        return "\(first.title) \(operation.symbol) \(second.title)"
    }

    var example: CalculationChallenge {
        if operation == .division {
            let (first, second) = orderedDigits
            if first == .two { return .init(left: 84, right: 21, operation: operation) }
            return .init(left: second == .two ? 432 : 864, right: second == .two ? 24 : 216, operation: operation)
        }
        let first = firstDigits == .two ? 47 : 247
        let second = secondDigits == .two ? 63 : 163
        return .init(left: operation.ordersLargestFirst ? max(first, second) : first,
                     right: operation.ordersLargestFirst ? min(first, second) : second,
                     operation: operation)
    }
}

struct CalculationChallenge: Equatable {
    let left: Int
    let right: Int
    var operation: CalculationOperation = .defaultValue

    var expression: String { "\(left) \(operation.symbol) \(right)" }
    var spokenExpression: String { "\(left) \(operation.spokenSymbol) \(right)" }
    var answer: Int {
        switch operation {
        case .addition: return left + right
        case .subtraction: return left - right
        case .multiplication: return left * right
        case .division: return left / right
        }
    }

    static func random(settings: CalculationSettings = .defaultValue) -> Self {
        let (firstDigits, secondDigits) = settings.orderedDigits
        if settings.operation == .division {
            let dividendRange = firstDigits.range
            // Construct an exact multiple in the chosen range. No retries, remainders, or ÷ 1 rounds.
            let divisor = Int.random(in: secondDigits.range.lowerBound...min(secondDigits.range.upperBound, dividendRange.upperBound / 2))
            let minimumQuotient = max(2, (dividendRange.lowerBound + divisor - 1) / divisor)
            let quotient = Int.random(in: minimumQuotient...(dividendRange.upperBound / divisor))
            return .init(left: divisor * quotient, right: divisor, operation: .division)
        }
        let first = Int.random(in: firstDigits.range)
        let second = Int.random(in: secondDigits.range)
        return .init(left: settings.operation.ordersLargestFirst ? max(first, second) : first,
                     right: settings.operation.ordersLargestFirst ? min(first, second) : second,
                     operation: settings.operation)
    }

    static func replacing(_ previous: Self, settings: CalculationSettings) -> Self {
        var next = random(settings: settings)
        // Changing both operands and the answer prevents reuse of the previous calculator result.
        while next.left == previous.left || next.right == previous.right || next.answer == previous.answer {
            next = random(settings: settings)
        }
        return next
    }

    func accepts(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.allSatisfy({ $0.isASCII && $0.isNumber }),
              let submitted = Int(trimmed) else { return false }
        return submitted == answer
    }
}
