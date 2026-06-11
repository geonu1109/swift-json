import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct JSONMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [
        JSONSchemaModelMacro.self,
        JSONSchemaPropertyMacro.self,
    ]
}
