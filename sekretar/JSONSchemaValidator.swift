import Foundation

/// JSON Schema validator for AI responses
/// Ensures all LLM responses conform to predefined schemas
public final class JSONSchemaValidator {

    // MARK: - Schema Types

    public enum SchemaType: String, CaseIterable {
        case intentDetection = "IntentDetection"
        case taskAnalysis = "TaskAnalysis"
        case eventParsing = "EventParsing"
        case scheduleOptimization = "ScheduleOptimization"

        var version: String { "v1" }

        var fileName: String {
            "\(rawValue).\(version).schema.json"
        }
    }

    // MARK: - Errors

    public enum ValidationError: LocalizedError {
        case schemaNotFound(SchemaType)
        case invalidSchema(SchemaType, String)
        case validationFailed(SchemaType, [String])
        case decodingFailed(String)
        case missingRequiredField(String)
        case invalidFieldType(field: String, expected: String, actual: String)
        case invalidEnumValue(field: String, value: Any, allowed: [String])
        case numberOutOfRange(field: String, value: Double, min: Double?, max: Double?)
        case stringTooLong(field: String, length: Int, maxLength: Int)
        case arrayTooLarge(field: String, count: Int, maxItems: Int)

        public var errorDescription: String? {
            switch self {
            case .schemaNotFound(let type):
                return "Schema not found: \(type.fileName)"
            case .invalidSchema(let type, let reason):
                return "Invalid schema \(type.fileName): \(reason)"
            case .validationFailed(let type, let errors):
                return "Validation failed for \(type.rawValue): \(errors.joined(separator: ", "))"
            case .decodingFailed(let reason):
                return "Failed to decode JSON: \(reason)"
            case .missingRequiredField(let field):
                return "Missing required field: \(field)"
            case .invalidFieldType(let field, let expected, let actual):
                return "Invalid type for \(field): expected \(expected), got \(actual)"
            case .invalidEnumValue(let field, let value, let allowed):
                return "Invalid value '\(value)' for \(field). Allowed: \(allowed.joined(separator: ", "))"
            case .numberOutOfRange(let field, let value, let min, let max):
                var range = ""
                if let min = min, let max = max {
                    range = "[\(min), \(max)]"
                } else if let min = min {
                    range = ">= \(min)"
                } else if let max = max {
                    range = "<= \(max)"
                }
                return "\(field) value \(value) out of range \(range)"
            case .stringTooLong(let field, let length, let maxLength):
                return "\(field) too long: \(length) characters (max: \(maxLength))"
            case .arrayTooLarge(let field, let count, let maxItems):
                return "\(field) has too many items: \(count) (max: \(maxItems))"
            }
        }
    }

    // MARK: - Properties

    private var schemas: [SchemaType: [String: Any]] = [:]
    private let schemasDirectory: URL

    // MARK: - Initialization

    public init() {
        // Get schemas directory
        if let bundleURL = Bundle.main.url(forResource: "AISchemas", withExtension: nil) {
            self.schemasDirectory = bundleURL
        } else {
            // Fallback to relative path during development
            let currentFile = URL(fileURLWithPath: #file)
            self.schemasDirectory = currentFile
                .deletingLastPathComponent()
                .appendingPathComponent("AISchemas")
        }

        // Load all schemas
        loadSchemas()
    }

    // MARK: - Public Methods

    /// Validate JSON data against a schema
    public func validate(_ data: Data, against schemaType: SchemaType) throws {
        guard let schema = schemas[schemaType] else {
            throw ValidationError.schemaNotFound(schemaType)
        }

        // Parse JSON
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw ValidationError.decodingFailed(error.localizedDescription)
        }

        // Validate against schema
        try validateObject(json, against: schema, path: "$")
    }

    /// Validate JSON string against a schema
    public func validate(_ jsonString: String, against schemaType: SchemaType) throws {
        guard let data = jsonString.data(using: .utf8) else {
            throw ValidationError.decodingFailed("Invalid UTF-8 string")
        }
        try validate(data, against: schemaType)
    }

    /// Validate and decode JSON to a specific type
    public func validateAndDecode<T: Decodable>(
        _ data: Data,
        against schemaType: SchemaType,
        as type: T.Type
    ) throws -> T {
        // First validate against schema
        try validate(data, against: schemaType)

        // Then decode to Swift type
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw ValidationError.decodingFailed(error.localizedDescription)
        }
    }

    // MARK: - Private Methods

    private func loadSchemas() {
        for schemaType in SchemaType.allCases {
            let schemaURL = schemasDirectory.appendingPathComponent(schemaType.fileName)

            guard let data = try? Data(contentsOf: schemaURL),
                  let json = try? JSONSerialization.jsonObject(with: data, options: []),
                  let schema = json as? [String: Any] else {
                print("Warning: Failed to load schema: \(schemaType.fileName)")
                continue
            }

            schemas[schemaType] = schema
        }
    }

    private func validateObject(_ value: Any, against schema: [String: Any], path: String) throws {
        // Get schema type
        let schemaType = schema["type"] as? String ?? "object"

        // Validate based on type
        switch schemaType {
        case "object":
            try validateObjectType(value, against: schema, path: path)
        case "array":
            try validateArrayType(value, against: schema, path: path)
        case "string":
            try validateStringType(value, against: schema, path: path)
        case "number":
            try validateNumberType(value, against: schema, path: path)
        case "integer":
            try validateIntegerType(value, against: schema, path: path)
        case "boolean":
            try validateBooleanType(value, against: schema, path: path)
        default:
            break
        }
    }

    private func validateObjectType(_ value: Any, against schema: [String: Any], path: String) throws {
        guard let object = value as? [String: Any] else {
            throw ValidationError.invalidFieldType(field: path, expected: "object", actual: String(describing: type(of: value)))
        }

        // Check required fields
        if let required = schema["required"] as? [String] {
            for field in required {
                if object[field] == nil {
                    throw ValidationError.missingRequiredField("\(path).\(field)")
                }
            }
        }

        // Validate properties
        if let properties = schema["properties"] as? [String: Any] {
            for (key, value) in object {
                let fieldPath = "\(path).\(key)"

                if let fieldSchema = properties[key] as? [String: Any] {
                    try validateObject(value, against: fieldSchema, path: fieldPath)
                } else if schema["additionalProperties"] as? Bool == false {
                    throw ValidationError.validationFailed(
                        .intentDetection,
                        ["Unexpected field: \(fieldPath)"]
                    )
                }
            }
        }
    }

    private func validateArrayType(_ value: Any, against schema: [String: Any], path: String) throws {
        guard let array = value as? [Any] else {
            throw ValidationError.invalidFieldType(field: path, expected: "array", actual: String(describing: type(of: value)))
        }

        // Check array size constraints
        if let maxItems = schema["maxItems"] as? Int, array.count > maxItems {
            throw ValidationError.arrayTooLarge(field: path, count: array.count, maxItems: maxItems)
        }

        if let minItems = schema["minItems"] as? Int, array.count < minItems {
            throw ValidationError.validationFailed(
                .intentDetection,
                ["\(path) has too few items: \(array.count) (min: \(minItems))"]
            )
        }

        // Validate items
        if let itemSchema = schema["items"] as? [String: Any] {
            for (index, item) in array.enumerated() {
                try validateObject(item, against: itemSchema, path: "\(path)[\(index)]")
            }
        }
    }

    private func validateStringType(_ value: Any, against schema: [String: Any], path: String) throws {
        guard let string = value as? String else {
            throw ValidationError.invalidFieldType(field: path, expected: "string", actual: String(describing: type(of: value)))
        }

        // Check string length
        if let maxLength = schema["maxLength"] as? Int, string.count > maxLength {
            throw ValidationError.stringTooLong(field: path, length: string.count, maxLength: maxLength)
        }

        // Check enum values
        if let enumValues = schema["enum"] as? [String], !enumValues.contains(string) {
            throw ValidationError.invalidEnumValue(field: path, value: string, allowed: enumValues)
        }

        // Validate format
        if let format = schema["format"] as? String {
            switch format {
            case "date-time":
                let formatter = ISO8601DateFormatter()
                if formatter.date(from: string) == nil {
                    throw ValidationError.validationFailed(
                        .intentDetection,
                        ["\(path) is not a valid ISO 8601 date-time"]
                    )
                }
            case "uuid":
                if UUID(uuidString: string) == nil {
                    throw ValidationError.validationFailed(
                        .intentDetection,
                        ["\(path) is not a valid UUID"]
                    )
                }
            case "email":
                let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
                let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
                if !predicate.evaluate(with: string) {
                    throw ValidationError.validationFailed(
                        .intentDetection,
                        ["\(path) is not a valid email address"]
                    )
                }
            default:
                break
            }
        }
    }

    private func validateNumberType(_ value: Any, against schema: [String: Any], path: String) throws {
        guard let number = value as? Double ?? (value as? Int).map(Double.init) else {
            throw ValidationError.invalidFieldType(field: path, expected: "number", actual: String(describing: type(of: value)))
        }

        // Check range
        let min = schema["minimum"] as? Double
        let max = schema["maximum"] as? Double

        if let min = min, number < min {
            throw ValidationError.numberOutOfRange(field: path, value: number, min: min, max: max)
        }

        if let max = max, number > max {
            throw ValidationError.numberOutOfRange(field: path, value: number, min: min, max: max)
        }
    }

    private func validateIntegerType(_ value: Any, against schema: [String: Any], path: String) throws {
        guard value is Int else {
            throw ValidationError.invalidFieldType(field: path, expected: "integer", actual: String(describing: type(of: value)))
        }

        // Integer validation uses the same logic as number
        try validateNumberType(value, against: schema, path: path)
    }

    private func validateBooleanType(_ value: Any, against schema: [String: Any], path: String) throws {
        guard value is Bool else {
            throw ValidationError.invalidFieldType(field: path, expected: "boolean", actual: String(describing: type(of: value)))
        }
    }
}

// MARK: - Convenience Extensions

extension JSONSchemaValidator {
    /// Validate an LLM provider response
    public func validateLLMResponse(_ response: String, for schemaType: SchemaType) -> Result<Data, ValidationError> {
        guard let data = response.data(using: .utf8) else {
            return .failure(.decodingFailed("Invalid UTF-8 string"))
        }

        do {
            try validate(data, against: schemaType)
            return .success(data)
        } catch let error as ValidationError {
            return .failure(error)
        } catch {
            return .failure(.validationFailed(schemaType, [error.localizedDescription]))
        }
    }
}