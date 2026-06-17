import Foundation

extension JSON: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(JSONNumber.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSON].self) {
            self = .array(value)
        } else {
            let keyed = try decoder.container(keyedBy: JSONCodingKey.self)
            var object = JSONObject()
            for key in keyed.allKeys {
                object[key.stringValue] = try keyed.decode(JSON.self, forKey: key)
            }
            self = .object(object)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        case let .bool(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .number(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .string(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .array(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .object(value):
            var container = encoder.container(keyedBy: JSONCodingKey.self)
            for (key, member) in value {
                try container.encode(member, forKey: JSONCodingKey(key))
            }
        }
    }
}

private struct JSONCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init(_ stringValue: String) { self.stringValue = stringValue }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

// MARK: - Bridging to/from arbitrary Codable types

public extension JSON {
    /// Build a `JSON` value from any `Encodable`.
    ///
    /// Object key order follows `JSONEncoder`'s output, which is not the
    /// property declaration order; use ``parse(_:)-(String)`` on JSON text when
    /// you need to preserve the source order.
    init(encodable value: some Encodable) throws {
        let data = try JSONEncoder().encode(value)
        self = try JSON.parse(data)
    }

    /// Decode this `JSON` value into any `Decodable` type.
    func decode<T: Decodable>(_ type: T.Type = T.self) throws -> T {
        try JSONDecoder().decode(T.self, from: data())
    }
}
