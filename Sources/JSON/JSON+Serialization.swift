import Foundation

public extension JSON {
    /// Parse a JSON string into a `JSON` value, preserving object key order.
    static func parse(_ string: String) throws -> JSON {
        try JSONParser.parse(string)
    }

    /// Parse JSON bytes (UTF-8) into a `JSON` value, preserving object key order.
    static func parse(_ data: Data) throws -> JSON {
        try JSONParser.parse(String(decoding: data, as: UTF8.self))
    }

    /// Serialize to a UTF-8 string, preserving object key order.
    func encoded(prettyPrinted: Bool = false) -> String {
        var output = ""
        JSON.write(self, into: &output, prettyPrinted: prettyPrinted, indent: 0)
        return output
    }

    /// Serialize to UTF-8 bytes, preserving object key order.
    func data(prettyPrinted: Bool = false) -> Data {
        Data(encoded(prettyPrinted: prettyPrinted).utf8)
    }
}

private extension JSON {
    static func write(_ value: JSON, into output: inout String, prettyPrinted: Bool, indent: Int) {
        switch value {
        case .null:
            output += "null"
        case let .bool(bool):
            output += bool ? "true" : "false"
        case let .number(number):
            output += number.description
        case let .string(string):
            writeString(string, into: &output)
        case let .array(array):
            writeArray(array, into: &output, prettyPrinted: prettyPrinted, indent: indent)
        case let .object(object):
            writeObject(object, into: &output, prettyPrinted: prettyPrinted, indent: indent)
        }
    }

    static func writeArray(_ array: [JSON], into output: inout String, prettyPrinted: Bool, indent: Int) {
        guard !array.isEmpty else { output += "[]"; return }
        output += "["
        let inner = indent + 1
        for (offset, element) in array.enumerated() {
            if offset > 0 { output += "," }
            newlineAndPad(&output, prettyPrinted: prettyPrinted, indent: inner)
            write(element, into: &output, prettyPrinted: prettyPrinted, indent: inner)
        }
        newlineAndPad(&output, prettyPrinted: prettyPrinted, indent: indent)
        output += "]"
    }

    static func writeObject(
        _ object: JSONObject,
        into output: inout String,
        prettyPrinted: Bool,
        indent: Int
    ) {
        guard !object.isEmpty else { output += "{}"; return }
        output += "{"
        let inner = indent + 1
        for (offset, pair) in object.enumerated() {
            if offset > 0 { output += "," }
            newlineAndPad(&output, prettyPrinted: prettyPrinted, indent: inner)
            writeString(pair.0, into: &output)
            output += prettyPrinted ? ": " : ":"
            write(pair.1, into: &output, prettyPrinted: prettyPrinted, indent: inner)
        }
        newlineAndPad(&output, prettyPrinted: prettyPrinted, indent: indent)
        output += "}"
    }

    static func newlineAndPad(_ output: inout String, prettyPrinted: Bool, indent: Int) {
        guard prettyPrinted else { return }
        output += "\n"
        output += String(repeating: "  ", count: indent)
    }

    static func writeString(_ string: String, into output: inout String) {
        output += "\""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"": output += "\\\""
            case "\\": output += "\\\\"
            case "\n": output += "\\n"
            case "\r": output += "\\r"
            case "\t": output += "\\t"
            case "\u{08}": output += "\\b"
            case "\u{0C}": output += "\\f"
            case let s where s.value < 0x20:
                output += String(format: "\\u%04x", s.value)
            default:
                output.unicodeScalars.append(scalar)
            }
        }
        output += "\""
    }
}

extension JSON: CustomStringConvertible {
    public var description: String { encoded() }
}

extension JSON: CustomDebugStringConvertible {
    public var debugDescription: String { encoded(prettyPrinted: true) }
}
