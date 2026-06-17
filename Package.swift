// swift-tools-version: 6.2
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
        // The directory / repo is `swift-json`, but the importable module is `JSON`.
        .library(name: "JSON", targets: ["JSON"]),
    ],
    dependencies: [
        // 602 has a prebuilt for the Swift 6.2+ toolchains, so consumers don't
        // recompile swift-syntax from source.
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0"),
    ],
    targets: [
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
        // The public library: JSON value model + JSONSchema + the macros.
        .target(name: "JSON", dependencies: ["JSONMacros"]),
        .testTarget(name: "JSONTests", dependencies: ["JSON"]),
    ],
    swiftLanguageModes: [.v6]
)
