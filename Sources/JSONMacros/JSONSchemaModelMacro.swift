import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

public struct JSONSchemaModelMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let source: String
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            source = try objectExtension(members: structDecl.memberBlock, type: type, attribute: node, protocols: protocols, context: context)
        } else if let classDecl = declaration.as(ClassDeclSyntax.self) {
            source = try objectExtension(members: classDecl.memberBlock, type: type, attribute: node, protocols: protocols, context: context)
        } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            source = try enumerationExtension(for: enumDecl, type: type, protocols: protocols)
        } else {
            throw MacroError("@JSONSchemaModel can only be applied to a struct, class, or raw-value enum")
        }

        let declSyntax: DeclSyntax = "\(raw: source)"
        guard let extensionDecl = declSyntax.as(ExtensionDeclSyntax.self) else {
            throw MacroError("Failed to synthesize JSONSchema extension")
        }
        return [extensionDecl]
    }
}

// MARK: - Struct → object schema

private func objectExtension(
    members: MemberBlockSyntax,
    type: some TypeSyntaxProtocol,
    attribute: AttributeSyntax,
    protocols: [TypeSyntax],
    context: some MacroExpansionContext
) throws -> String {
    let additionalProperties = boolArgument(named: "additionalProperties", in: attribute) ?? false
    let keyMap = codingKeys(in: members)
    var propertyEntries: [String] = []
    var requiredKeys: [String] = []

    for member in members.members {
        guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
        if isTypeLevel(variable.modifiers) { continue }
        let description = jsonSchemaPropertyDescription(in: variable.attributes)

        for binding in variable.bindings {
            // Computed properties have no stored value to describe.
            guard binding.accessorBlock == nil,
                  let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }

            let name = pattern.identifier.text

            // Respect CodingKeys: omitted properties aren't part of the JSON.
            let jsonName: String
            if let keyMap {
                guard let mapped = keyMap[name] else { continue }
                jsonName = mapped
            } else {
                jsonName = name
            }

            // Resolve the type from the annotation, or infer it from a literal.
            let typeExpression: String
            let isOptional: Bool
            if let typeAnnotation = binding.typeAnnotation {
                let (wrapped, optional) = unwrapOptional(typeAnnotation.type)
                typeExpression = canonicalTypeExpression(wrapped)
                isOptional = optional
            } else if let inferred = inferredLiteralType(from: binding.initializer?.value) {
                typeExpression = inferred
                isOptional = false
            } else {
                context.diagnose(Diagnostic(
                    node: Syntax(binding),
                    message: MacroWarning(message: "Property '\(name)' has no type annotation and its type couldn't be inferred, so it is omitted from the JSON schema. Add an explicit type annotation to include it.")
                ))
                continue
            }

            var schemaExpression = "\(typeExpression).resolveSchema(in: context)"
            if let description {
                schemaExpression += ".with(description: \(swiftStringLiteral(description)))"
            }

            propertyEntries.append("(\(swiftStringLiteral(jsonName)), \(schemaExpression))")
            if !isOptional {
                requiredKeys.append(jsonName)
            }
        }
    }

    let propertiesBlock = propertyEntries.isEmpty
        ? "[]"
        : "[\n" + propertyEntries.map { "                \($0)" }.joined(separator: ",\n") + "\n            ]"
    let requiredBlock = "[" + requiredKeys.map(swiftStringLiteral).joined(separator: ", ") + "]"

    return """
    extension \(type.trimmed)\(conformanceClause(protocols)) {
        public static func resolveSchema(in context: JSONSchemaContext) -> JSONSchema {
            context.reference(name: String(describing: Self.self), id: ObjectIdentifier(Self.self)) {
                .object(
                    properties: \(propertiesBlock),
                    required: \(requiredBlock),
                    additionalProperties: \(additionalProperties)
                )
            }
        }
    }
    """
}

// MARK: - Raw-value enum → enum schema

private func enumerationExtension(
    for enumDecl: EnumDeclSyntax,
    type: some TypeSyntaxProtocol,
    protocols: [TypeSyntax]
) throws -> String {
    guard let rawType = rawValueType(of: enumDecl) else {
        throw MacroError("@JSONSchemaModel on an enum requires a String or integer raw type")
    }

    var valueExpressions: [String] = []
    var nextImplicitInt = 0

    for member in enumDecl.memberBlock.members {
        guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else { continue }
        for element in caseDecl.elements {
            if element.parameterClause != nil {
                throw MacroError("@JSONSchemaModel cannot describe enum cases with associated values")
            }
            let caseName = element.name.text
            let rawLiteral = element.rawValue?.value

            switch rawType {
            case .string:
                if let stringLiteral = rawLiteral?.as(StringLiteralExprSyntax.self),
                   let value = stringLiteral.representedLiteralValue {
                    valueExpressions.append("JSON.string(\(swiftStringLiteral(value)))")
                } else {
                    valueExpressions.append("JSON.string(\(swiftStringLiteral(caseName)))")
                }
            case .integer:
                let value: Int
                if let intLiteral = rawLiteral?.as(IntegerLiteralExprSyntax.self),
                   let parsed = Int(intLiteral.literal.text.replacingOccurrences(of: "_", with: "")) {
                    value = parsed
                } else {
                    value = nextImplicitInt
                }
                valueExpressions.append("JSON.number(.integer(\(value)))")
                nextImplicitInt = value + 1
            }
        }
    }

    let valuesBlock = valueExpressions.isEmpty
        ? "[]"
        : "[\n" + valueExpressions.map { "                \($0)" }.joined(separator: ",\n") + "\n            ]"
    let schemaType = rawType == .string ? "string" : "integer"

    return """
    extension \(type.trimmed)\(conformanceClause(protocols)) {
        public static func resolveSchema(in context: JSONSchemaContext) -> JSONSchema {
            .enumeration(\(valuesBlock), type: \(swiftStringLiteral(schemaType)))
        }
    }
    """
}

private enum RawType {
    case string
    case integer
}

private func rawValueType(of enumDecl: EnumDeclSyntax) -> RawType? {
    guard let inheritance = enumDecl.inheritanceClause else { return nil }
    let integerTypes: Set<String> = [
        "Int", "Int8", "Int16", "Int32", "Int64",
        "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
    ]
    for inherited in inheritance.inheritedTypes {
        let name = inherited.type.trimmedDescription
        if name == "String" { return .string }
        if integerTypes.contains(name) { return .integer }
    }
    return nil
}
