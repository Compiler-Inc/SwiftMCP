import Foundation

/// Represents a JSON value
public enum JSON: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case number(Double)
    case bool(Bool)
    case array([JSON])
    case object([String: JSON])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let array = try? container.decode([JSON].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSON].self) {
            self = .object(object)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .string(string):
            try container.encode(string)
        case let .int(number):
            try container.encode(number)
        case let .number(number):
            try container.encode(number)
        case let .bool(bool):
            try container.encode(bool)
        case let .array(array):
            try container.encode(array)
        case let .object(object):
            try container.encode(object)
        case .null:
            try container.encodeNil()
        }
    }
}
