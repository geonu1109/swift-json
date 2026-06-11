import Foundation

/// An error encountered while parsing a JSON string.
public struct JSONParseError: Error, CustomStringConvertible, Equatable {
    public let message: String
    /// Scalar offset into the input where parsing failed.
    public let offset: Int

    public var description: String { "JSON parse error at offset \(offset): \(message)" }
}

/// A small recursive-descent parser.
///
/// Foundation's `JSONDecoder` does not preserve object key order, so this hand
/// written parser is used by ``JSON/parse(_:)-(String)`` to keep objects in
/// document order.
struct JSONParser {
    private let scalars: [Unicode.Scalar]
    private var index = 0

    init(_ string: String) {
        scalars = Array(string.unicodeScalars)
    }

    static func parse(_ string: String) throws -> JSON {
        var parser = JSONParser(string)
        parser.skipWhitespace()
        let value = try parser.parseValue()
        parser.skipWhitespace()
        guard parser.index == parser.scalars.count else {
            throw parser.error("unexpected trailing characters")
        }
        return value
    }

    // MARK: - Values

    private mutating func parseValue() throws -> JSON {
        guard let scalar = peek() else { throw error("unexpected end of input") }
        switch scalar {
        case "{": return try parseObject()
        case "[": return try parseArray()
        case "\"": return .string(try parseString())
        case "t", "f": return .bool(try parseBool())
        case "n": try parseNull(); return .null
        case "-", "0"..."9": return .number(try parseNumber())
        default: throw error("unexpected character '\(scalar)'")
        }
    }

    private mutating func parseObject() throws -> JSON {
        index += 1 // consume '{'
        var object = JSONObject()
        skipWhitespace()
        if peek() == "}" { index += 1; return .object(object) }
        while true {
            skipWhitespace()
            guard peek() == "\"" else { throw error("expected object key") }
            let key = try parseString()
            skipWhitespace()
            guard peek() == ":" else { throw error("expected ':' after object key") }
            index += 1
            skipWhitespace()
            object[key] = try parseValue()
            skipWhitespace()
            switch peek() {
            case ",": index += 1
            case "}": index += 1; return .object(object)
            default: throw error("expected ',' or '}' in object")
            }
        }
    }

    private mutating func parseArray() throws -> JSON {
        index += 1 // consume '['
        var elements: [JSON] = []
        skipWhitespace()
        if peek() == "]" { index += 1; return .array(elements) }
        while true {
            skipWhitespace()
            elements.append(try parseValue())
            skipWhitespace()
            switch peek() {
            case ",": index += 1
            case "]": index += 1; return .array(elements)
            default: throw error("expected ',' or ']' in array")
            }
        }
    }

    private mutating func parseString() throws -> String {
        index += 1 // consume opening quote
        var result = String.UnicodeScalarView()
        while let scalar = peek() {
            index += 1
            switch scalar {
            case "\"":
                return String(result)
            case "\\":
                result.append(try parseEscape())
            default:
                result.append(scalar)
            }
        }
        throw error("unterminated string")
    }

    private mutating func parseEscape() throws -> Unicode.Scalar {
        guard let scalar = peek() else { throw error("unterminated escape") }
        index += 1
        switch scalar {
        case "\"": return "\""
        case "\\": return "\\"
        case "/": return "/"
        case "n": return "\n"
        case "t": return "\t"
        case "r": return "\r"
        case "b": return "\u{08}"
        case "f": return "\u{0C}"
        case "u": return try parseUnicodeEscape()
        default: throw error("invalid escape '\\\(scalar)'")
        }
    }

    private mutating func parseUnicodeEscape() throws -> Unicode.Scalar {
        let first = try parseHex4()
        // Combine UTF-16 surrogate pairs into a single scalar.
        if (0xD800...0xDBFF).contains(first) {
            guard peek() == "\\" else { throw error("expected low surrogate") }
            index += 1
            guard peek() == "u" else { throw error("expected low surrogate") }
            index += 1
            let second = try parseHex4()
            let combined = 0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00)
            guard let scalar = Unicode.Scalar(combined) else { throw error("invalid surrogate pair") }
            return scalar
        }
        guard let scalar = Unicode.Scalar(first) else { throw error("invalid unicode escape") }
        return scalar
    }

    private mutating func parseHex4() throws -> Int {
        var value = 0
        for _ in 0..<4 {
            guard let scalar = peek(), let digit = scalar.hexDigitValue else {
                throw error("invalid unicode escape")
            }
            value = value * 16 + digit
            index += 1
        }
        return value
    }

    private mutating func parseNumber() throws -> JSONNumber {
        let start = index
        var isFloatingPoint = false
        if peek() == "-" { index += 1 }
        while let scalar = peek() {
            switch scalar {
            case "0"..."9": index += 1
            case ".", "e", "E", "+", "-": isFloatingPoint = true; index += 1
            default: break
            }
            if !(isContinuationOfNumber(peek())) { break }
        }
        let text = String(String.UnicodeScalarView(scalars[start..<index]))
        if !isFloatingPoint, let integer = Int(text) {
            return .integer(integer)
        }
        guard let double = Double(text) else { throw error("invalid number '\(text)'") }
        return .floatingPoint(double)
    }

    private func isContinuationOfNumber(_ scalar: Unicode.Scalar?) -> Bool {
        guard let scalar else { return false }
        switch scalar {
        case "0"..."9", ".", "e", "E", "+", "-": return true
        default: return false
        }
    }

    private mutating func parseBool() throws -> Bool {
        if matches("true") { return true }
        if matches("false") { return false }
        throw error("invalid literal")
    }

    private mutating func parseNull() throws {
        guard matches("null") else { throw error("invalid literal") }
    }

    // MARK: - Primitives

    private func peek() -> Unicode.Scalar? {
        index < scalars.count ? scalars[index] : nil
    }

    private mutating func matches(_ literal: String) -> Bool {
        let literalScalars = Array(literal.unicodeScalars)
        guard index + literalScalars.count <= scalars.count else { return false }
        for (offset, scalar) in literalScalars.enumerated() where scalars[index + offset] != scalar {
            return false
        }
        index += literalScalars.count
        return true
    }

    private mutating func skipWhitespace() {
        while let scalar = peek(), scalar == " " || scalar == "\n" || scalar == "\r" || scalar == "\t" {
            index += 1
        }
    }

    private func error(_ message: String) -> JSONParseError {
        JSONParseError(message: message, offset: index)
    }
}

private extension Unicode.Scalar {
    var hexDigitValue: Int? {
        switch self {
        case "0"..."9": return Int(value - 0x30)
        case "a"..."f": return Int(value - 0x61 + 10)
        case "A"..."F": return Int(value - 0x41 + 10)
        default: return nil
        }
    }
}
