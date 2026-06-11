// Re-export JSON so a single `import JSONSchemaMacro` brings the JSON value
// model and the JSONSchema / JSONSchemaRepresentable types into scope alongside
// the macros below.
@_exported import JSON

/// Synthesizes a ``JSONSchemaRepresentable`` conformance for a `struct`,
/// `class`, or raw-value `enum`.
///
/// For a struct or class, each stored property becomes a schema property;
/// non-optional properties are marked `required`. For a raw-value enum (with a
/// `String` or integer raw type), an `enum` schema of the raw values is
/// generated. Recursive types are emitted with `$ref`/`$defs`.
///
/// ```swift
/// @JSONSchemaModel
/// struct Person {
///     var name: String
///     @JSONSchemaProperty(description: "Years since birth")
///     var age: Int
///     var nickname: String?
/// }
///
/// print(Person.jsonSchema)
/// ```
///
/// - Parameter additionalProperties: Whether the generated object schema
///   permits properties beyond those declared. Defaults to `false`.
@attached(extension, conformances: JSONSchemaRepresentable, names: named(resolveSchema(in:)))
public macro JSONSchemaModel(additionalProperties: Bool = false) = #externalMacro(
    module: "JSONMacros",
    type: "JSONSchemaModelMacro"
)

/// Annotates a property handled by ``JSONSchemaModel`` with a description.
///
/// This is a peer marker macro; it produces no code on its own and is read by
/// ``JSONSchemaModel`` during expansion.
@attached(peer)
public macro JSONSchemaProperty(description: String? = nil) = #externalMacro(
    module: "JSONMacros",
    type: "JSONSchemaPropertyMacro"
)
