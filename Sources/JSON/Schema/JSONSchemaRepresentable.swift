/// Accumulates `$defs` and tracks in-progress types while a schema is built, so
/// that recursive (self- or mutually-referential) types terminate instead of
/// looping forever.
///
/// Acyclic types are inlined. A type is promoted into `$defs` (and referenced
/// via `$ref`) only once a cycle back to it is detected, keeping output for the
/// common, non-recursive case clean.
public final class JSONSchemaContext {
    private var defs = JSONObject()
    private var inProgress: Set<String> = []
    private var cyclic: Set<String> = []
    /// Maps each distinct type to the (possibly disambiguated) `$defs` name it
    /// was assigned, so two different types that share a simple name don't
    /// clobber each other.
    private var assignedNames: [ObjectIdentifier: String] = [:]
    private var usedNames: Set<String> = []

    public init() {}

    /// Resolve a named model type, breaking cycles with `$ref`/`$defs`.
    /// - Parameters:
    ///   - name: The type's preferred name (used as the `$defs` key; an
    ///     unambiguous suffix is appended if another type already claimed it).
    ///   - id: A stable identity for the type, used to detect name collisions
    ///     between distinct types.
    ///   - build: Builds the type's schema; may recursively resolve other types.
    public func reference(name preferredName: String, id: ObjectIdentifier, build: () -> JSONSchema) -> JSONSchema {
        let name = resolvedName(preferredName, for: id)
        if defs[name] != nil {
            return .ref(name) // already promoted to $defs
        }
        if inProgress.contains(name) {
            cyclic.insert(name) // back-edge: this type participates in a cycle
            return .ref(name)
        }

        inProgress.insert(name)
        let built = build()
        inProgress.remove(name)

        if cyclic.contains(name) {
            defs[name] = built.json
            return .ref(name)
        }
        return built // acyclic: inline
    }

    private func resolvedName(_ preferred: String, for id: ObjectIdentifier) -> String {
        if let existing = assignedNames[id] { return existing }
        var candidate = preferred
        var suffix = 2
        while usedNames.contains(candidate) {
            candidate = "\(preferred)_\(suffix)"
            suffix += 1
        }
        usedNames.insert(candidate)
        assignedNames[id] = candidate
        return candidate
    }

    /// Attach the collected `$defs` (if any) to the root schema.
    public func finalize(root: JSONSchema) -> JSONSchema {
        guard !defs.isEmpty, case var .object(object) = root.json else { return root }
        object["$defs"] = .object(defs)
        return JSONSchema(.object(object))
    }
}

/// A type that can describe itself as a ``JSONSchema``.
///
/// Primitive types, `Optional`, `Array`, `Set`, and `[String: Value]` conform
/// out of the box. Apply the ``JSONSchemaModel`` macro to your own `struct`s and
/// raw-value `enum`s to synthesize a conformance — including correct handling of
/// recursive types via `$ref`/`$defs`.
public protocol JSONSchemaRepresentable {
    /// Contribute this type's schema to `context`, returning the schema to use
    /// at the reference site (either an inline schema or a `$ref`).
    static func resolveSchema(in context: JSONSchemaContext) -> JSONSchema
}

public extension JSONSchemaRepresentable {
    /// The complete JSON Schema for this type, with any `$defs` attached.
    static var jsonSchema: JSONSchema {
        let context = JSONSchemaContext()
        let root = resolveSchema(in: context)
        return context.finalize(root: root)
    }
}

// MARK: - Primitive conformances

extension String: JSONSchemaRepresentable {
    public static func resolveSchema(in context: JSONSchemaContext) -> JSONSchema { .string }
}

extension Bool: JSONSchemaRepresentable {
    public static func resolveSchema(in context: JSONSchemaContext) -> JSONSchema { .boolean }
}

extension Double: JSONSchemaRepresentable {
    public static func resolveSchema(in context: JSONSchemaContext) -> JSONSchema { .number }
}

extension Float: JSONSchemaRepresentable {
    public static func resolveSchema(in context: JSONSchemaContext) -> JSONSchema { .number }
}

extension Int: JSONSchemaRepresentable {
    public static func resolveSchema(in context: JSONSchemaContext) -> JSONSchema { .integer }
}

extension Int8: JSONSchemaRepresentable {
    public static func resolveSchema(in context: JSONSchemaContext) -> JSONSchema { .integer }
}

extension Int16: JSONSchemaRepresentable {
    public static func resolveSchema(in context: JSONSchemaContext) -> JSONSchema { .integer }
}

extension Int32: JSONSchemaRepresentable {
    public static func resolveSchema(in context: JSONSchemaContext) -> JSONSchema { .integer }
}

extension Int64: JSONSchemaRepresentable {
    public static func resolveSchema(in context: JSONSchemaContext) -> JSONSchema { .integer }
}

extension UInt: JSONSchemaRepresentable {
    public static func resolveSchema(in context: JSONSchemaContext) -> JSONSchema { .integer }
}

extension UInt8: JSONSchemaRepresentable {
    public static func resolveSchema(in context: JSONSchemaContext) -> JSONSchema { .integer }
}

extension UInt16: JSONSchemaRepresentable {
    public static func resolveSchema(in context: JSONSchemaContext) -> JSONSchema { .integer }
}

extension UInt32: JSONSchemaRepresentable {
    public static func resolveSchema(in context: JSONSchemaContext) -> JSONSchema { .integer }
}

extension UInt64: JSONSchemaRepresentable {
    public static func resolveSchema(in context: JSONSchemaContext) -> JSONSchema { .integer }
}

// MARK: - Container conformances

extension Optional: JSONSchemaRepresentable where Wrapped: JSONSchemaRepresentable {
    /// An optional contributes the wrapped schema; whether the property is
    /// `required` is decided by the enclosing object schema.
    public static func resolveSchema(in context: JSONSchemaContext) -> JSONSchema {
        Wrapped.resolveSchema(in: context)
    }
}

extension Array: JSONSchemaRepresentable where Element: JSONSchemaRepresentable {
    public static func resolveSchema(in context: JSONSchemaContext) -> JSONSchema {
        .array(of: Element.resolveSchema(in: context))
    }
}

extension Set: JSONSchemaRepresentable where Element: JSONSchemaRepresentable {
    public static func resolveSchema(in context: JSONSchemaContext) -> JSONSchema {
        .array(of: Element.resolveSchema(in: context)).with("uniqueItems", true)
    }
}

extension Dictionary: JSONSchemaRepresentable
where Key == String, Value: JSONSchemaRepresentable {
    public static func resolveSchema(in context: JSONSchemaContext) -> JSONSchema {
        .map(of: Value.resolveSchema(in: context))
    }
}
