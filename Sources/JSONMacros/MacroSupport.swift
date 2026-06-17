import SwiftSyntax
import SwiftDiagnostics

struct MacroError: Error, CustomStringConvertible {
    let message: String
    init(_ message: String) { self.message = message }
    var description: String { message }
}

/// A warning surfaced during macro expansion.
struct MacroWarning: DiagnosticMessage {
    let message: String
    let severity: DiagnosticSeverity = .warning
    var diagnosticID: MessageID { MessageID(domain: "JSONMacros", id: "JSONSchemaModel.warning") }
}

/// Read a `CodingKeys` enum, mapping each property name to its JSON key.
///
/// Returns `nil` when the type declares no `CodingKeys`, in which case property
/// names are used verbatim. When present, properties absent from `CodingKeys`
/// are excluded from the schema — matching `Codable`'s own behavior.
func codingKeys(in members: MemberBlockSyntax) -> [String: String]? {
    for member in members.members {
        guard let enumDecl = member.decl.as(EnumDeclSyntax.self),
              enumDecl.name.text == "CodingKeys" else { continue }

        var map: [String: String] = [:]
        for enumMember in enumDecl.memberBlock.members {
            guard let caseDecl = enumMember.decl.as(EnumCaseDeclSyntax.self) else { continue }
            for element in caseDecl.elements {
                let propertyName = element.name.text
                if let rawValue = element.rawValue?.value.as(StringLiteralExprSyntax.self),
                   let mapped = rawValue.representedLiteralValue {
                    map[propertyName] = mapped
                } else {
                    map[propertyName] = propertyName
                }
            }
        }
        return map
    }
    return nil
}

/// Best-effort type inference for a property declared without an annotation,
/// based on its literal initializer (e.g. `var count = 0` → `Int`).
func inferredLiteralType(from initializer: ExprSyntax?) -> String? {
    guard let initializer else { return nil }
    if initializer.is(IntegerLiteralExprSyntax.self) { return "Int" }
    if initializer.is(FloatLiteralExprSyntax.self) { return "Double" }
    if initializer.is(StringLiteralExprSyntax.self) { return "String" }
    if initializer.is(BooleanLiteralExprSyntax.self) { return "Bool" }
    return nil
}

/// Render a Swift `String` literal (with escaping) for emission into generated source.
func swiftStringLiteral(_ value: String) -> String {
    var escaped = ""
    for character in value {
        switch character {
        case "\\": escaped += "\\\\"
        case "\"": escaped += "\\\""
        case "\n": escaped += "\\n"
        case "\r": escaped += "\\r"
        case "\t": escaped += "\\t"
        default: escaped.append(character)
        }
    }
    return "\"\(escaped)\""
}

/// Read a labeled `Bool` literal argument from an attribute, if present.
func boolArgument(named name: String, in attribute: AttributeSyntax) -> Bool? {
    guard case let .argumentList(arguments) = attribute.arguments else { return nil }
    for argument in arguments where argument.label?.text == name {
        guard let literal = argument.expression.as(BooleanLiteralExprSyntax.self) else { continue }
        return literal.literal.tokenKind == .keyword(.true)
    }
    return nil
}

/// Read the `description` from a `@JSONSchemaProperty(...)` attached to a property.
func jsonSchemaPropertyDescription(in attributes: AttributeListSyntax) -> String? {
    for element in attributes {
        guard case let .attribute(attribute) = element,
              attribute.attributeName.trimmedDescription == "JSONSchemaProperty",
              case let .argumentList(arguments) = attribute.arguments else { continue }
        for argument in arguments where argument.label?.text == "description" {
            if let literal = argument.expression.as(StringLiteralExprSyntax.self) {
                return literal.representedLiteralValue
            }
        }
    }
    return nil
}

/// Render a type as an expression on which a static member can be accessed.
///
/// Array/dictionary *sugar* (`[T]`, `[K: V]`) is ambiguous in expression
/// position — `[Person].jsonSchema` parses `[Person]` as an array literal. The
/// generic spelling (`Array<Person>`) is unambiguous. Only the outermost layer
/// needs rewriting; sugar nested inside `<...>` is already in type position.
func canonicalTypeExpression(_ type: TypeSyntax) -> String {
    if let array = type.as(ArrayTypeSyntax.self) {
        return "Array<\(array.element.trimmed.description)>"
    }
    if let dictionary = type.as(DictionaryTypeSyntax.self) {
        return "Dictionary<\(dictionary.key.trimmed.description), \(dictionary.value.trimmed.description)>"
    }
    return type.trimmed.description
}

/// Strip a single layer of optionality from a type, reporting whether it was optional.
func unwrapOptional(_ type: TypeSyntax) -> (wrapped: TypeSyntax, isOptional: Bool) {
    if let optional = type.as(OptionalTypeSyntax.self) {
        return (optional.wrappedType, true)
    }
    if let optional = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
        return (optional.wrappedType, true)
    }
    return (type, false)
}

/// True if the declaration carries a `static` or `class` modifier.
func isTypeLevel(_ modifiers: DeclModifierListSyntax) -> Bool {
    modifiers.contains { modifier in
        modifier.name.tokenKind == .keyword(.static) || modifier.name.tokenKind == .keyword(.class)
    }
}

/// The conformance clause to emit, based on which conformances the compiler still needs.
func conformanceClause(_ protocols: [TypeSyntax]) -> String {
    protocols.isEmpty ? "" : ": JSONSchemaRepresentable"
}
