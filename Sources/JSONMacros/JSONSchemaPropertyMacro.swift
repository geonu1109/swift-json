import SwiftSyntax
import SwiftSyntaxMacros

/// A marker peer macro. It emits no code of its own — `@JSONSchemaModel` reads
/// its arguments during expansion. Declaring it as a peer macro is what lets it
/// be attached to a property.
public struct JSONSchemaPropertyMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}
