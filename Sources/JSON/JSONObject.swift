/// The backing store for a JSON object: a `String`-keyed map that **preserves
/// insertion order** for serialization while treating keys as **unique**.
///
/// Order is a presentational property here, not a semantic one — so two objects
/// with the same members in a different order are `==` and hash equally (like a
/// `Dictionary`), even though each serializes in its own order. Setting an
/// existing key updates it in place; parsing input with a duplicate key keeps
/// the first position and the last value.
public struct JSONObject: Sendable {
    public private(set) var keys: [String]
    private var storage: [String: JSON]

    public init() {
        keys = []
        storage = [:]
    }

    public init(_ pairs: [(String, JSON)]) {
        self.init()
        for (key, value) in pairs {
            self[key] = value
        }
    }

    public subscript(key: String) -> JSON? {
        get { storage[key] }
        set {
            if let newValue {
                if storage[key] == nil { keys.append(key) }
                storage[key] = newValue
            } else if storage[key] != nil {
                keys.removeAll { $0 == key }
                storage[key] = nil
            }
        }
    }

    /// Values in key order.
    public var values: [JSON] { keys.map { storage[$0]! } }
    public var count: Int { keys.count }
    public var isEmpty: Bool { keys.isEmpty }

    /// A plain, unordered dictionary copy.
    public var dictionary: [String: JSON] { storage }
}

extension JSONObject: Sequence {
    /// Iterates members in key order.
    public func makeIterator() -> AnyIterator<(String, JSON)> {
        var index = 0
        return AnyIterator {
            guard index < keys.count else { return nil }
            defer { index += 1 }
            let key = keys[index]
            return (key, storage[key]!)
        }
    }
}

extension JSONObject: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSON)...) {
        self.init(elements)
    }
}

// Equality and hashing ignore key order — JSON objects are unordered by spec,
// so order is presentational only and must not affect value identity.
extension JSONObject: Equatable {
    public static func == (lhs: JSONObject, rhs: JSONObject) -> Bool {
        lhs.storage == rhs.storage
    }
}

extension JSONObject: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(storage)
    }
}
