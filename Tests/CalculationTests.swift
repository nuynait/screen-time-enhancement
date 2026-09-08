import Foundation
import XCTest
@testable import GateCore

final class CalculationTests: XCTestCase {
    func testReplacementChangesBothNumbersAndRejectsPreviousAnswerForEveryConfiguration() {
        for operation in CalculationOperation.allCases {
            for first in CalculationDigits.allCases {
                for second in CalculationDigits.allCases {
                    let settings = CalculationSettings(firstDigits: first, secondDigits: second, operation: operation)
                    var previous = settings.example
                    for _ in 0..<100 {
                        let next = CalculationChallenge.replacing(previous, settings: settings)
                        XCTAssertNotEqual(next.left, previous.left)
                        XCTAssertNotEqual(next.right, previous.right)
                        XCTAssertFalse(next.accepts(String(previous.answer)))
                        verify(next, first: first, second: second, operation: operation)
                        previous = next
                    }
                }
            }
        }
    }

    func testAllOperationsAndDigitPairsProduceValidVariedChallenges() {
        for operation in CalculationOperation.allCases {
            for first in CalculationDigits.allCases {
                for second in CalculationDigits.allCases {
                    let settings = CalculationSettings(firstDigits: first, secondDigits: second, operation: operation)
                    var expressions = Set<String>()
                    for _ in 0..<500 {
                        let problem = CalculationChallenge.random(settings: settings)
                        verify(problem, first: first, second: second, operation: operation)
                        expressions.insert(problem.expression)
                    }
                    XCTAssertGreaterThan(expressions.count, 20)
                    verify(settings.example, first: first, second: second, operation: operation)
                }
            }
        }
    }

    private func verify(_ problem: CalculationChallenge, first: CalculationDigits, second: CalculationDigits, operation: CalculationOperation) {
        XCTAssertEqual(problem.operation, operation)
        if operation == .addition || operation == .multiplication {
            XCTAssertTrue(first.range.contains(problem.left))
            XCTAssertTrue(second.range.contains(problem.right))
        } else {
            XCTAssertTrue((first.range.contains(problem.left) && second.range.contains(problem.right))
                          || (second.range.contains(problem.left) && first.range.contains(problem.right)))
            XCTAssertGreaterThanOrEqual(problem.left, problem.right)
        }
        let expected: Int
        switch operation {
        case .addition: expected = problem.left + problem.right
        case .subtraction: expected = problem.left - problem.right
        case .multiplication: expected = problem.left * problem.right
        case .division:
            XCTAssertGreaterThan(problem.right, 0)
            XCTAssertEqual(problem.left % problem.right, 0)
            XCTAssertGreaterThanOrEqual(problem.left / problem.right, 2)
            expected = problem.left / problem.right
        }
        XCTAssertTrue(problem.accepts(String(expected)))
        XCTAssertFalse(problem.accepts(String(expected + 1)))
        XCTAssertFalse(problem.accepts("\(expected).0"))
    }

    func testZeroDifferenceAndLargestProductAreAccepted() {
        XCTAssertTrue(CalculationChallenge(left: 999, right: 999, operation: .subtraction).accepts("0"))
        XCTAssertTrue(CalculationChallenge(left: 999, right: 999).accepts("998001"))
        XCTAssertFalse(CalculationChallenge(left: 864, right: 216, operation: .division).accepts("3"))
    }

    func testPreferenceEncodingDefaultsAndMalformedValues() throws {
        for operation in CalculationOperation.allCases {
            let data = try JSONEncoder().encode(operation)
            XCTAssertEqual(String(decoding: data, as: UTF8.self), "\"\(operation.rawValue)\"")
            XCTAssertEqual(try JSONDecoder().decode(CalculationOperation.self, from: data), operation)
        }
        for digits in CalculationDigits.allCases {
            let data = try JSONEncoder().encode(digits)
            XCTAssertEqual(String(decoding: data, as: UTF8.self), String(digits.rawValue))
            XCTAssertEqual(try JSONDecoder().decode(CalculationDigits.self, from: data), digits)
        }
        XCTAssertEqual(try JSONDecoder().decode(CalculationOperation.self, from: Data("\"future\"".utf8)), .multiplication)
        XCTAssertEqual(try JSONDecoder().decode(CalculationDigits.self, from: Data("4".utf8)), .two)
        XCTAssertThrowsError(try JSONDecoder().decode(CalculationOperation.self, from: Data("42".utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(CalculationDigits.self, from: Data("\"three\"".utf8)))
        XCTAssertEqual(CalculationSettings.defaultValue.example, CalculationChallenge(left: 47, right: 63))
    }
}
