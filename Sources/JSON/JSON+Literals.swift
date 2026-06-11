/// Literal conformances let you write JSON inline, e.g.
/// `let value: JSON = ["name": "Ada", "age": 36, "admin": true]`.

extension JSON: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) { self = .null }
}

extension JSON: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension JSON: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .number(.integer(value)) }
}

extension JSON: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) { self = .number(.floatingPoint(value)) }
}

extension JSON: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}

extension JSON: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSON...) { self = .array(elements) }
}

extension JSON: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSON)...) {
        self = .object(JSONObject(elements))
    }
}
