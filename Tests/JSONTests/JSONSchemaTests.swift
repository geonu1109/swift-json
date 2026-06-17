import Testing
import JSON

@JSONSchemaModel
struct Person {
    var name: String
    @JSONSchemaProperty(description: "Years since birth")
    var age: Int
    var nickname: String?
    var scores: [Double]
    var active: Bool
}

@JSONSchemaModel(additionalProperties: true)
struct Loose {
    var id: String
}

@JSONSchemaModel
enum Role: String {
    case admin
    case member
    case guest = "visitor"
}

@JSONSchemaModel
enum Priority: Int {
    case low
    case medium = 5
    case high
}

@JSONSchemaModel
struct Team {
    var lead: Person
    var members: [Person]
}

// CodingKeys remap property names and exclude properties they omit.
@JSONSchemaModel
struct APIUser {
    var id: String
    var displayName: String
    var internalNote: String = ""

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

// Properties without annotations but with literal initializers are inferred.
@JSONSchemaModel
struct Defaults {
    var count = 0
    var ratio = 1.5
    var label = "x"
    var enabled = true
}

// Recursive: a node referencing itself through an array.
@JSONSchemaModel
struct TreeNode {
    var value: String
    var children: [TreeNode]
}

// Recursive: a self-reference through an optional (linked list). A struct can't
// store itself inline, so a recursive optional reference must be a class.
@JSONSchemaModel
final class ListNode {
    var value: Int = 0
    var next: ListNode?
}

// Mutually recursive types.
@JSONSchemaModel
struct Author {
    var name: String
    var books: [Book]
}

@JSONSchemaModel
struct Book {
    var title: String
    var author: Author
}

@Suite("JSONSchema generation")
struct JSONSchemaTests {
    @Test("Struct schema lists properties, types, and required keys")
    func structSchema() {
        let schema = Person.jsonSchema.json
        #expect(schema["type"]?.stringValue == "object")
        #expect(schema["additionalProperties"]?.boolValue == false)

        let properties = schema["properties"]
        #expect(properties?["name"]?["type"]?.stringValue == "string")
        #expect(properties?["age"]?["type"]?.stringValue == "integer")
        #expect(properties?["age"]?["description"]?.stringValue == "Years since birth")
        #expect(properties?["nickname"]?["type"]?.stringValue == "string")
        #expect(properties?["scores"]?["type"]?.stringValue == "array")
        #expect(properties?["scores"]?["items"]?["type"]?.stringValue == "number")

        // Optionals are not required.
        let required = schema["required"]?.arrayValue?.compactMap(\.stringValue)
        #expect(required == ["name", "age", "scores", "active"])
    }

    @Test("additionalProperties argument is honored")
    func additionalProperties() {
        #expect(Loose.jsonSchema.json["additionalProperties"]?.boolValue == true)
    }

    @Test("String raw-value enum becomes an enum schema")
    func stringEnumSchema() {
        let schema = Role.jsonSchema.json
        #expect(schema["type"]?.stringValue == "string")
        let values = schema["enum"]?.arrayValue?.compactMap(\.stringValue)
        #expect(values == ["admin", "member", "visitor"])
    }

    @Test("Integer raw-value enum infers implicit values")
    func intEnumSchema() {
        let schema = Priority.jsonSchema.json
        #expect(schema["type"]?.stringValue == "integer")
        let values = schema["enum"]?.arrayValue?.compactMap(\.intValue)
        #expect(values == [0, 5, 6])
    }

    @Test("Nested @JSONSchemaModel types compose")
    func nestedSchema() {
        let schema = Team.jsonSchema.json
        let lead = schema["properties"]?["lead"]
        #expect(lead?["type"]?.stringValue == "object")
        #expect(lead?["properties"]?["name"]?["type"]?.stringValue == "string")

        let members = schema["properties"]?["members"]
        #expect(members?["type"]?.stringValue == "array")
        #expect(members?["items"]?["type"]?.stringValue == "object")
    }

    @Test("Self-recursive type terminates with $ref/$defs")
    func selfRecursion() {
        // The mere fact this returns (rather than crashing with a stack
        // overflow) is the headline assertion.
        let schema = TreeNode.jsonSchema.json

        // Root is a $ref into $defs.
        #expect(schema["$ref"]?.stringValue == "#/$defs/TreeNode")
        let def = schema["$defs"]?["TreeNode"]
        #expect(def?["type"]?.stringValue == "object")
        // The recursive edge points back at the definition.
        #expect(def?["properties"]?["children"]?["items"]?["$ref"]?.stringValue == "#/$defs/TreeNode")
    }

    @Test("Optional self-reference terminates")
    func optionalRecursion() {
        let schema = ListNode.jsonSchema.json
        #expect(schema["$ref"]?.stringValue == "#/$defs/ListNode")
        let def = schema["$defs"]?["ListNode"]
        #expect(def?["properties"]?["next"]?["$ref"]?.stringValue == "#/$defs/ListNode")
        // `next` is optional, so it isn't required.
        let required = def?["required"]?.arrayValue?.compactMap(\.stringValue)
        #expect(required == ["value"])
    }

    @Test("Mutually recursive types terminate")
    func mutualRecursion() {
        let schema = Author.jsonSchema.json
        // Author is promoted to $defs because the cycle returns to it.
        #expect(schema["$ref"]?.stringValue == "#/$defs/Author")
        let author = schema["$defs"]?["Author"]
        let bookItems = author?["properties"]?["books"]?["items"]
        // Book is inlined inside Author, and its author edge refers back.
        #expect(bookItems?["properties"]?["author"]?["$ref"]?.stringValue == "#/$defs/Author")
    }

    @Test("CodingKeys remap and exclude properties")
    func codingKeys() {
        let schema = APIUser.jsonSchema.json
        let properties = schema["properties"]
        #expect(properties?["id"]?["type"]?.stringValue == "string")
        // Renamed via CodingKeys.
        #expect(properties?["display_name"]?["type"]?.stringValue == "string")
        #expect(properties?["displayName"] == nil)
        // Omitted from CodingKeys → excluded entirely.
        #expect(properties?["internalNote"] == nil)

        let required = schema["required"]?.arrayValue?.compactMap(\.stringValue)
        #expect(required == ["id", "display_name"])
    }

    @Test("Literal initializers infer property types")
    func inferredTypes() {
        let properties = Defaults.jsonSchema.json["properties"]
        #expect(properties?["count"]?["type"]?.stringValue == "integer")
        #expect(properties?["ratio"]?["type"]?.stringValue == "number")
        #expect(properties?["label"]?["type"]?.stringValue == "string")
        #expect(properties?["enabled"]?["type"]?.stringValue == "boolean")
    }
}
