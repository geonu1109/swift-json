import Foundation

/// A JSON number that remembers whether it was written as an integer or a
/// floating-point value, so `42` and `42.0` don't silently collapse into one.
public enum JSONNumber: Sendable, Hashable {
    case integer(Int)
    case floatingPoint(Double)
}

public extension JSONNumber {
    /// The value as an `Int`, truncated toward zero — or `nil` if a
    /// floating-point value is non-finite or outside `Int`'s range. Never traps.
    var intValue: Int? {
        switch self {
        case let .integer(value): value
        case let .floatingPoint(value): value.isFinite ? Int(exactly: value.rounded(.towardZero)) : nil
        }
    }

    /// The value as a `Double`.
    var doubleValue: Double {
        switch self {
        case let .integer(value): Double(value)
        case let .floatingPoint(value): value
        }
    }
}

extension JSONNumber: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else {
            self = .floatingPoint(try container.decode(Double.self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .integer(value): try container.encode(value)
        case let .floatingPoint(value): try container.encode(value)
        }
    }
}

extension JSONNumber: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .integer(value) }
}

extension JSONNumber: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) { self = .floatingPoint(value) }
}

extension JSONNumber: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .integer(value): String(value)
        case let .floatingPoint(value): String(value)
        }
    }
}
