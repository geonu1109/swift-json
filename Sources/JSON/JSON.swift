import Foundation

/// A value-type model for any JSON value.
///
/// Unlike `Foundation`'s `Any`-typed JSON, this is a closed, `Sendable`,
/// `Hashable` enum you can pattern-match, build with literals, and round-trip
/// through `Codable` while preserving object key order and integer/float intent.
public indirect enum JSON: Sendable, Hashable {
    case null
    case bool(Bool)
    case number(JSONNumber)
    case string(String)
    case array([JSON])
    case object(JSONObject)
}

// MARK: - Convenience constructors

public extension JSON {
    static func number(_ value: Int) -> JSON { .number(.integer(value)) }
    static func number(_ value: Double) -> JSON { .number(.floatingPoint(value)) }
}

// MARK: - Typed accessors

public extension JSON {
    var isNull: Bool { self == .null }

    var boolValue: Bool? {
        guard case let .bool(value) = self else { return nil }
        return value
    }

    var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }

    var numberValue: JSONNumber? {
        guard case let .number(value) = self else { return nil }
        return value
    }

    /// An `Int`, parsing from a numeric string if necessary.
    var intValue: Int? {
        switch self {
        case let .number(value): value.intValue
        case let .string(value): Int(value)
        default: nil
        }
    }

    /// A `Double`, parsing from a numeric string if necessary.
    var doubleValue: Double? {
        switch self {
        case let .number(value): value.doubleValue
        case let .string(value): Double(value)
        default: nil
        }
    }

    var arrayValue: [JSON]? {
        guard case let .array(value) = self else { return nil }
        return value
    }

    var objectValue: JSONObject? {
        guard case let .object(value) = self else { return nil }
        return value
    }
}

// MARK: - Subscripts

public extension JSON {
    /// Access a member of a JSON object. Returns `nil` for non-objects or
    /// missing keys; setting on a non-object is a no-op.
    subscript(key: String) -> JSON? {
        get {
            guard case let .object(object) = self else { return nil }
            return object[key]
        }
        set {
            guard case var .object(object) = self else { return }
            object[key] = newValue
            self = .object(object)
        }
    }

    /// Access an element of a JSON array by index. Out-of-bounds and
    /// non-arrays return `nil` rather than trapping.
    subscript(index: Int) -> JSON? {
        guard case let .array(array) = self, array.indices.contains(index) else { return nil }
        return array[index]
    }
}
