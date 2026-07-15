import Foundation

/// Parser for Valve's text KeyValues format (VDF), used by loginusers.vdf,
/// libraryfolders.vdf, and appmanifest_*.acf. No Swift library exists for this
/// format, so this is a small hand-rolled recursive-descent parser.
indirect enum VDFValue {
    case string(String)
    case object([String: VDFValue])

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var objectValue: [String: VDFValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    subscript(key: String) -> VDFValue? {
        objectValue?[key]
    }
}

enum VDFParseError: Error, LocalizedError {
    case unexpectedEndOfInput
    case unexpectedToken(String)

    var errorDescription: String? {
        switch self {
        case .unexpectedEndOfInput:
            return "Unexpected end of VDF input"
        case .unexpectedToken(let description):
            return "Unexpected VDF token: \(description)"
        }
    }
}

enum VDFParser {
    static func parse(_ text: String) throws -> [String: VDFValue] {
        var tokenizer = VDFTokenizer(text)
        return try parseObjectBody(&tokenizer, isRoot: true)
    }

    private static func parseObjectBody(_ tokenizer: inout VDFTokenizer, isRoot: Bool) throws -> [String: VDFValue] {
        var result: [String: VDFValue] = [:]
        while let token = tokenizer.next() {
            if case .closeBrace = token {
                if isRoot { throw VDFParseError.unexpectedToken("}") }
                return result
            }
            guard case .string(let key) = token else {
                throw VDFParseError.unexpectedToken("expected key")
            }
            guard let valueToken = tokenizer.next() else {
                throw VDFParseError.unexpectedEndOfInput
            }
            switch valueToken {
            case .string(let value):
                result[key] = .string(value)
            case .openBrace:
                result[key] = .object(try parseObjectBody(&tokenizer, isRoot: false))
            case .closeBrace:
                throw VDFParseError.unexpectedToken("}")
            }
        }
        if !isRoot { throw VDFParseError.unexpectedEndOfInput }
        return result
    }
}

private enum VDFToken {
    case string(String)
    case openBrace
    case closeBrace
}

private struct VDFTokenizer {
    private let characters: [Character]
    private var index = 0

    init(_ text: String) {
        characters = Array(text)
    }

    mutating func next() -> VDFToken? {
        skipWhitespaceAndComments()
        guard index < characters.count else { return nil }
        let character = characters[index]
        if character == "{" {
            index += 1
            return .openBrace
        }
        if character == "}" {
            index += 1
            return .closeBrace
        }
        if character == "\"" {
            return .string(readQuotedString())
        }
        return .string(readUnquotedToken())
    }

    private mutating func skipWhitespaceAndComments() {
        while index < characters.count {
            let character = characters[index]
            if character.isWhitespace {
                index += 1
            } else if character == "/", index + 1 < characters.count, characters[index + 1] == "/" {
                while index < characters.count, characters[index] != "\n" {
                    index += 1
                }
            } else {
                break
            }
        }
    }

    private mutating func readQuotedString() -> String {
        index += 1 // skip opening quote
        var result = ""
        while index < characters.count {
            let character = characters[index]
            if character == "\\", index + 1 < characters.count {
                result.append(characters[index + 1])
                index += 2
                continue
            }
            if character == "\"" {
                index += 1
                break
            }
            result.append(character)
            index += 1
        }
        return result
    }

    private mutating func readUnquotedToken() -> String {
        var result = ""
        while index < characters.count, !characters[index].isWhitespace, characters[index] != "{", characters[index] != "}" {
            result.append(characters[index])
            index += 1
        }
        return result
    }
}
