# swift-json

**English** · [한국어](README.ko.md)

A value-type JSON model for Swift, plus a macro that generates [JSON Schema](https://json-schema.org) from your types.

> The directory and repo are named `swift-json`, but the importable module is **`JSON`**:
>
> ```swift
> import JSON
> ```

## Why

Swift has two ways to deal with JSON, and a gap between them.

- **`Codable`** is excellent when you know the shape ahead of time. It gets awkward the moment the shape is dynamic, only partially known, or you need to *hold and manipulate* arbitrary JSON — merge two payloads, pluck one field out of a webhook, assemble a request body at runtime.
- **`JSONSerialization`** hands you `Any` / `[String: Any]`. You force-cast at every access, it isn't `Sendable`, it can't be pattern-matched, it collapses the integer-vs-float distinction (`42` becomes indistinguishable from `42.0`), and it doesn't preserve object key order.

And neither addresses a third need: **producing a JSON Schema from your Swift types.** LLM tool/function calling, request validation, and API documentation all want a schema that matches your model — and hand-writing that schema means it silently drifts out of sync with the type it's supposed to describe.

## What it gives you

1. **`JSON` — a value type for arbitrary JSON.** A closed `enum` (`null` / `bool` / `number` / `string` / `array` / `object`) that is `Sendable`, `Hashable`, and `Codable`; pattern-matchable; built from literals; read through safe accessors and subscripts; and round-tripped through an order-preserving parser and serializer. No `Any`, no force-casts, no lost type information.
2. **`@JSONSchemaModel` — a schema that can't drift.** Annotate a type and its JSON Schema (draft 2020-12) is synthesized at compile time from the actual stored properties.

## Installation

Swift Package Manager — add the package:

```swift
dependencies: [
    .package(url: "https://github.com/geonu1109/swift-json.git", from: "1.0.0"),
],
```

then depend on the `JSON` product:

```swift
.target(name: "YourTarget", dependencies: [
    .product(name: "JSON", package: "swift-json"),
]),
```

A single `import JSON` gives you the value model, the JSONSchema types, and the `@JSONSchemaModel` macro. The macro is built on [swift-syntax](https://github.com/swiftlang/swift-syntax), but on a Swift 6.2+ toolchain SwiftPM fetches it as a **prebuilt** binary — your build doesn't recompile it from source.

In Xcode: **File ▸ Add Package Dependencies…**, then paste the repository URL.

## Usage

### The `JSON` value

```swift
import JSON

var value: JSON = [
    "name": "Ada",
    "age": 36,
    "tags": ["math", "engines"],
    "manager": nil,
]

value["name"]?.stringValue        // "Ada"
value["age"]?.intValue            // 36
value["tags"]?[1]?.stringValue    // "engines"
value["new"] = "added"            // mutate in place

let text = value.encoded(prettyPrinted: true)   // ordered, pretty JSON
let parsed = try JSON.parse(text)               // order-preserving parser
```

Bridge to and from any `Codable` type:

```swift
struct Point: Codable { var x, y: Int }
let json = try JSON(encodable: Point(x: 1, y: 2))
let point = try json.decode(Point.self)
```

### The `@JSONSchemaModel` macro

Attach `@JSONSchemaModel` to a `struct`, `class`, or raw-value `enum` to synthesize a `JSONSchemaRepresentable` conformance, giving the type a `static var jsonSchema: JSONSchema`.

```swift
import JSON

@JSONSchemaModel
struct Person {
    var name: String
    @JSONSchemaProperty(description: "Years since birth")
    var age: Int
    var nickname: String?     // optional → not in `required`
    var scores: [Double]
}

print(Person.jsonSchema.encoded())
```

```json
{
  "type": "object",
  "properties": {
    "name": { "type": "string" },
    "age": { "type": "integer", "description": "Years since birth" },
    "nickname": { "type": "string" },
    "scores": { "type": "array", "items": { "type": "number" } }
  },
  "required": ["name", "age", "scores"],
  "additionalProperties": false
}
```

- Non-optional stored properties become `required`.
- `[T]`, `[String: V]`, `Set<T>`, and nested `@JSONSchemaModel` types compose automatically.
- Raw-value enums (`String`/integer) become `enum` schemas; implicit integer values are inferred.
- `@JSONSchemaModel(additionalProperties: true)` relaxes the object.
- A `CodingKeys` enum is honored: properties are renamed to their coding key, and properties omitted from `CodingKeys` are excluded (matching `Codable`).
- An un-annotated property is inferred from a literal initializer (`var count = 0` → integer); anything not inferable emits a build warning naming it, rather than being dropped silently.

Self-referential and mutually recursive types are handled with `$ref`/`$defs`, so generation always terminates:

```swift
@JSONSchemaModel
struct TreeNode {
    var value: String
    var children: [TreeNode]
}
// → { "$ref": "#/$defs/TreeNode", "$defs": { "TreeNode": { … "items": { "$ref": "#/$defs/TreeNode" } } } }
```

(A `struct` can only recurse through a heap-backed type such as `Array`; for an optional self-reference like a linked list, use a `class`.) Use `JSONSchema` directly for anything the macro doesn't cover:

```swift
let schema = JSONSchema.object(
    properties: [("id", .string), ("count", .integer)],
    required: ["id"]
).with(description: "A record")
```

## How it works

- **`JSON`** is a closed `indirect enum`. Objects use `JSONObject` — an insertion-ordered, unique-key store — and numbers carry an integer/floating-point tag so the two never merge.
- **Parsing and serialization** are a hand-written recursive-descent pass rather than `JSONSerialization`, because Foundation does not preserve object key order.
- **The macro** is a [swift-syntax](https://github.com/swiftlang/swift-syntax) compiler plugin (`JSONMacros`), shipped inside the `JSON` module so a single import covers everything; on Swift 6.2+ SwiftPM uses a prebuilt swift-syntax rather than building it from source. Each model contributes its schema through a `JSONSchemaContext` that tracks in-progress types, breaking a cycle with a `$ref` into a `$defs` section while keeping acyclic types inlined.

## Guarantees & semantics

These are the behaviors you can rely on (and the criteria the test suite checks):

- **Array element order** is always preserved.
- **Object key order** is preserved through `JSON.parse(_:)` and `encoded()`.
  - ⚠️ Decoding a `JSON` value nested inside another `Codable` type via a foreign decoder (e.g. Foundation's `JSONDecoder`) does **not** preserve key order — Foundation surfaces keys unordered. Use `JSON.parse(_:)` when order matters.
- **Object keys are unique.** Parsing input with duplicate names keeps the first position and the last value: `{"a":1,"a":2}` → `{"a":2}`. This follows RFC 8259 ("names SHOULD be unique") and matches common parser behavior.
- **Object equality ignores key order.** `["a": 1, "b": 2] == ["b": 2, "a": 1]` — objects are unordered by spec, so order is a *presentational* property: it drives serialization but not `==` / `hashValue`. (Arrays remain order-sensitive.)
- **`42` and `42.0` stay distinct** (`JSONNumber.integer` vs `.floatingPoint`), surviving parse and serialization.
- **The parser is strict and bounded.** It rejects malformed numbers (`01`, `1.`, `+1`, `1e`), unescaped control characters, and values that overflow to non-finite; it caps nesting depth (128) so adversarial input can't overflow the stack. Accessors never trap — `intValue` returns `nil` for non-finite or out-of-range values, and non-finite numbers serialize to `null` rather than invalid JSON.

### Limitations

- **Number precision.** Numbers are stored as `Int` or `Double`. Integers beyond `Int`'s range (or decimals beyond `Double`'s precision) fall back to `Double` and lose precision — the same tradeoff as JavaScript's `JSON.parse`.
- **Macro `$defs` names** use the type's simple name; two distinct types sharing a name get a numeric suffix (`Foo`, `Foo_2`).
- **Macro type inference** covers scalar literals (`Int`, `Double`, `String`, `Bool`); other un-annotated properties need an explicit annotation (you'll get a build warning for any skipped).
- **Models nested inside another type** that reference a sibling/self by its simple name can fail to compile, because the generated extension lives at file scope (`A.B` isn't `B` there). Declare `@JSONSchemaModel` types at file scope.

## Requirements

Swift 6.2+ · macOS 13 / iOS 16 / tvOS 16 / watchOS 9 / visionOS 1. Depends on [swift-syntax](https://github.com/swiftlang/swift-syntax) for the macro; on a 6.2+ toolchain SwiftPM fetches it as a prebuilt binary, so it isn't recompiled from source.
