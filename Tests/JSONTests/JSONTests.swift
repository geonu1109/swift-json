import Testing
@testable import JSON

@Suite("JSON value model")
struct JSONValueTests {
    @Test("Literals build the expected cases")
    func literals() {
        let value: JSON = [
            "name": "Ada",
            "age": 36,
            "score": 9.5,
            "admin": true,
            "tags": ["math", "engines"],
            "manager": nil,
        ]

        #expect(value["name"]?.stringValue == "Ada")
        #expect(value["age"]?.intValue == 36)
        #expect(value["score"]?.doubleValue == 9.5)
        #expect(value["admin"]?.boolValue == true)
        #expect(value["tags"]?[1]?.stringValue == "engines")
        #expect(value["manager"] == JSON.null)
    }

    @Test("Integer and float numbers stay distinct")
    func numberKinds() {
        #expect(JSON.number(42) == JSON.number(.integer(42)))
        #expect(JSON.number(42.0) == JSON.number(.floatingPoint(42.0)))
        #expect(JSON.number(42) != JSON.number(42.0))
    }

    @Test("Out-of-bounds and wrong-type access returns nil, never traps")
    func safeAccess() {
        let array: JSON = [1, 2, 3]
        #expect(array[5] == nil)
        #expect(array["key"] == nil)

        let scalar: JSON = "plain"
        #expect(scalar[0] == nil)
        #expect(scalar["key"] == nil)
    }

    @Test("Round-trips through parse and encode preserving key order")
    func roundTrip() throws {
        let source = #"{"z":1,"a":2,"nested":{"b":[true,null,"x"]}}"#
        let parsed = try JSON.parse(source)
        #expect(parsed.encoded() == source)
    }

    @Test("Pretty printing indents nested structures")
    func prettyPrint() {
        let value: JSON = ["a": [1, 2]]
        let expected = """
        {
          "a": [
            1,
            2
          ]
        }
        """
        #expect(value.encoded(prettyPrinted: true) == expected)
    }

    @Test("String escaping handles control characters and quotes")
    func escaping() {
        let value: JSON = .string("line1\nline2\t\"quoted\"\\")
        #expect(value.encoded() == #""line1\nline2\t\"quoted\"\\""#)
    }

    @Test("Object equality ignores key order; serialization preserves it")
    func orderInsensitiveEquality() {
        let ab: JSON = ["a": 1, "b": 2]
        let ba: JSON = ["b": 2, "a": 1]
        // Same value (objects are unordered by spec)…
        #expect(ab == ba)
        #expect(ab.hashValue == ba.hashValue)
        // …but each serializes in its own authored order.
        #expect(ab.encoded() == #"{"a":1,"b":2}"#)
        #expect(ba.encoded() == #"{"b":2,"a":1}"#)
        // Arrays remain order-sensitive.
        #expect((["x", "y"] as JSON) != (["y", "x"] as JSON))
    }

    @Test("Schemas can be built and composed without the macro")
    func manualSchema() {
        // Primitive and container conformances live in the JSON module (no macro).
        #expect(String.jsonSchema.json["type"]?.stringValue == "string")
        #expect([Int].jsonSchema.json["type"]?.stringValue == "array")
        #expect([Int].jsonSchema.json["items"]?["type"]?.stringValue == "integer")

        let schema = JSONSchema.object(
            properties: [("id", .string), ("count", .integer)],
            required: ["id"]
        ).with(description: "A record")
        #expect(schema.json["properties"]?["id"]?["type"]?.stringValue == "string")
        #expect(schema.json["required"]?.arrayValue?.compactMap(\.stringValue) == ["id"])
        #expect(schema.json["description"]?.stringValue == "A record")
    }

    @Test("Bridges to and from Codable types")
    func codableBridge() throws {
        struct Point: Codable, Equatable { var x: Int; var y: Int }
        let point = Point(x: 1, y: 2)
        let json = try JSON(encodable: point)
        #expect(json["x"]?.intValue == 1)
        #expect(try json.decode(Point.self) == point)
    }
}

@Suite("Parser robustness & number safety")
struct ParserRobustnessTests {
    @Test("Rejects malformed numbers")
    func malformedNumbers() {
        for bad in ["01", "00", "1.", "-", "+1", "1e", "1e+", "1.2.3", "0x10", ".5", "1."] {
            #expect(throws: (any Error).self) { _ = try JSON.parse("[\(bad)]") }
        }
    }

    @Test("Accepts valid number forms")
    func validNumbers() throws {
        #expect(try JSON.parse("0").numberValue == .integer(0))
        #expect(try JSON.parse("-0.5").doubleValue == -0.5)
        #expect(try JSON.parse("1e3").doubleValue == 1000)
        #expect(try JSON.parse("-12").intValue == -12)
    }

    @Test("Rejects numbers that overflow to non-finite")
    func nonFiniteRejected() {
        #expect(throws: (any Error).self) { _ = try JSON.parse("1e1000") }
    }

    @Test("Caps nesting depth instead of crashing")
    func depthLimit() {
        let deep = String(repeating: "[", count: 5000) + String(repeating: "]", count: 5000)
        #expect(throws: (any Error).self) { _ = try JSON.parse(deep) }
    }

    @Test("Rejects unescaped control characters in strings")
    func controlCharacters() {
        #expect(throws: (any Error).self) { _ = try JSON.parse("\"a\u{01}b\"") }
    }

    @Test("Non-finite numbers serialize to null and never trap intValue")
    func nonFiniteSafe() {
        let infinity: JSON = .number(.floatingPoint(.infinity))
        #expect(infinity.encoded() == "null")     // not the invalid token "inf"
        #expect(infinity.intValue == nil)          // previously trapped
        #expect(JSON.number(.floatingPoint(.nan)).encoded() == "null")
    }

    @Test("Out-of-range float intValue is nil, fractional truncates toward zero")
    func intValueSafety() {
        #expect(JSON.number(.floatingPoint(1e300)).intValue == nil)
        #expect(JSON.number(42.9).intValue == 42)
        #expect(JSON.number(-42.9).intValue == -42)
    }
}
