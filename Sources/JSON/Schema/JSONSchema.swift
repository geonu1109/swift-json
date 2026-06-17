/// A JSON Schema document, modeled directly on top of ``JSON``.
///
/// The shape follows JSON Schema draft 2020-12. Build schemas with the
/// factories below, or generate them automatically with the ``JSONSchemaModel``
/// macro.
public struct JSONSchema: Sendable, Hashable, Codable {
    /// The schema as a raw ``JSON`` value.
    public var json: JSON

    /// Wrap a raw ``JSON`` value as a schema.
    public init(_ json: JSON) {
        self.json = json
    }
}

// MARK: - Primitive factories

public extension JSONSchema {
    static let string = JSONSchema(["type": "string"])
    static let integer = JSONSchema(["type": "integer"])
    static let number = JSONSchema(["type": "number"])
    static let boolean = JSONSchema(["type": "boolean"])

    /// An array schema whose elements match `items`.
    static func array(of items: JSONSchema) -> JSONSchema {
        JSONSchema(["type": "array", "items": items.json])
    }

    /// An object schema.
    /// - Parameters:
    ///   - properties: Property name → schema, in declaration order.
    ///   - required: The property names that must be present.
    ///   - additionalProperties: Whether properties beyond those declared are allowed.
    static func object(
        properties: [(String, JSONSchema)],
        required: [String] = [],
        additionalProperties: Bool = false
    ) -> JSONSchema {
        var props = JSONObject()
        for (name, schema) in properties {
            props[name] = schema.json
        }
        var object: JSONObject = ["type": "object"]
        object["properties"] = .object(props)
        if !required.isEmpty {
            object["required"] = .array(required.map(JSON.string))
        }
        object["additionalProperties"] = .bool(additionalProperties)
        return JSONSchema(.object(object))
    }

    /// An object schema whose values all match `valueSchema` (a free-form map).
    static func map(of valueSchema: JSONSchema) -> JSONSchema {
        JSONSchema(["type": "object", "additionalProperties": valueSchema.json])
    }

    /// A reference to a named schema in the document's `$defs` section.
    static func ref(_ name: String) -> JSONSchema {
        JSONSchema(["$ref": .string("#/$defs/\(name)")])
    }

    /// An enumeration of allowed values.
    static func enumeration(_ values: [JSON], type: String? = nil) -> JSONSchema {
        var object = JSONObject()
        if let type { object["type"] = .string(type) }
        object["enum"] = .array(values)
        return JSONSchema(.object(object))
    }
}

// MARK: - Modifiers

public extension JSONSchema {
    /// Return a copy with a `description` annotation attached.
    func with(description: String?) -> JSONSchema {
        guard let description, case var .object(object) = json else { return self }
        object["description"] = .string(description)
        return JSONSchema(.object(object))
    }

    /// Return a copy with an arbitrary keyword set (e.g. `format`, `minimum`).
    func with(_ keyword: String, _ value: JSON) -> JSONSchema {
        guard case var .object(object) = json else { return self }
        object[keyword] = value
        return JSONSchema(.object(object))
    }

    /// The schema rendered as a JSON string.
    func encoded(prettyPrinted: Bool = true) -> String {
        json.encoded(prettyPrinted: prettyPrinted)
    }
}

extension JSONSchema: CustomStringConvertible {
    public var description: String { encoded() }
}
