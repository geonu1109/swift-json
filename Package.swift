// swift-tools-version: 6.0
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "swift-json",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1),
    ],
    products: [
        // The JSON value model and the JSONSchema types — no external dependencies.
        .library(name: "JSON", targets: ["JSON"]),
        // Adds the @JSONSchemaModel macro (pulls in swift-syntax). Re-exports JSON.
        .library(name: "JSONSchemaMacro", targets: ["JSONSchemaMacro"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        // The core library: JSON value type + JSONSchema / JSONSchemaRepresentable.
        // Deliberately has no dependency on swift-syntax.
        .target(name: "JSON"),

        // Compiler-plugin implementation of the macros.
        .macro(
            name: "JSONMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
            ]
        ),

        // Public macro declarations. Depending on this is what pulls swift-syntax
        // into a consumer's build, so it's opt-in.
        .target(name: "JSONSchemaMacro", dependencies: ["JSON", "JSONMacros"]),

        .testTarget(name: "JSONTests", dependencies: ["JSON"]),
        .testTarget(name: "JSONSchemaMacroTests", dependencies: ["JSONSchemaMacro"]),
    ],
    swiftLanguageModes: [.v6]
)
