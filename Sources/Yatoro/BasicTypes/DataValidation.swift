import Foundation

/// Data validation utilities
public class DataValidator {
    
    /// Validation result
    public enum ValidationResult {
        case valid
        case invalid(String)
        
        public var isValid: Bool {
            switch self {
            case .valid:
                return true
            case .invalid:
                return false
            }
        }
        
        public var errorMessage: String? {
            switch self {
            case .valid:
                return nil
            case .invalid(let message):
                return message
            }
        }
    }
    
    /// Validate search query
    public static func validateSearchQuery(_ query: String) -> ValidationResult {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return .invalid("Search query cannot be empty")
        }
        
        if trimmed.count > 200 {
            return .invalid("Search query too long (max 200 characters)")
        }
        
        // Check for potentially problematic characters
        let invalidChars = CharacterSet(charactersIn: "<>\"'`\\;")
        if trimmed.rangeOfCharacter(from: invalidChars) != nil {
            return .invalid("Search query contains invalid characters")
        }
        
        return .valid
    }
    
    /// Validate command input
    public static func validateCommand(_ command: String) -> ValidationResult {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return .invalid("Command cannot be empty")
        }
        
        if trimmed.count > 100 {
            return .invalid("Command too long (max 100 characters)")
        }
        
        // Check command format
        let commandPattern = "^[a-zA-Z][a-zA-Z0-9_]*$"
        let regex = try? NSRegularExpression(pattern: commandPattern)
        let range = NSRange(location: 0, length: trimmed.count)
        
        if regex?.firstMatch(in: trimmed, range: range) == nil {
            return .invalid("Invalid command format")
        }
        
        return .valid
    }
    
    /// Validate file path
    public static func validateFilePath(_ path: String) -> ValidationResult {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return .invalid("File path cannot be empty")
        }
        
        if trimmed.count > 1000 {
            return .invalid("File path too long (max 1000 characters)")
        }
        
        // Check for directory traversal
        if trimmed.contains("../") || trimmed.contains("..\\") {
            return .invalid("Directory traversal not allowed")
        }
        
        // Check for null bytes
        if trimmed.contains("\0") {
            return .invalid("Null bytes not allowed in file path")
        }
        
        return .valid
    }
    
    /// Validate URL
    public static func validateURL(_ urlString: String) -> ValidationResult {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return .invalid("URL cannot be empty")
        }
        
        guard let url = URL(string: trimmed) else {
            return .invalid("Invalid URL format")
        }
        
        guard let scheme = url.scheme?.lowercased() else {
            return .invalid("URL must have a scheme")
        }
        
        let allowedSchemes = ["http", "https", "file"]
        if !allowedSchemes.contains(scheme) {
            return .invalid("URL scheme not allowed")
        }
        
        return .valid
    }
    
    /// Validate configuration value
    public static func validateConfigValue<T>(_ value: T, for key: String) -> ValidationResult {
        switch key {
        case "theme":
            guard let theme = value as? String else {
                return .invalid("Theme must be a string")
            }
            return validateTheme(theme)
            
        case "volume":
            guard let volume = value as? Double else {
                return .invalid("Volume must be a number")
            }
            return validateVolume(volume)
            
        case "bufferSize":
            guard let size = value as? Int else {
                return .invalid("Buffer size must be an integer")
            }
            return validateBufferSize(size)
            
        default:
            return .valid // Unknown keys pass validation
        }
    }
    
    /// Validate theme name
    private static func validateTheme(_ theme: String) -> ValidationResult {
        let validThemes = ["default", "dark", "light", "high-contrast", "colorful"]
        
        if !validThemes.contains(theme) {
            return .invalid("Unknown theme: \(theme)")
        }
        
        return .valid
    }
    
    /// Validate volume level
    private static func validateVolume(_ volume: Double) -> ValidationResult {
        if volume < 0.0 || volume > 1.0 {
            return .invalid("Volume must be between 0.0 and 1.0")
        }
        
        return .valid
    }
    
    /// Validate buffer size
    private static func validateBufferSize(_ size: Int) -> ValidationResult {
        if size <= 0 {
            return .invalid("Buffer size must be positive")
        }
        
        if size > 100000 {
            return .invalid("Buffer size too large (max 100000)")
        }
        
        return .valid
    }
}

/// Music item validation
public class MusicItemValidator {
    
    /// Validate music item data
    public static func validateMusicItem(_ item: [String: Any]) -> DataValidator.ValidationResult {
        // Check required fields
        guard let title = item["title"] as? String, !title.isEmpty else {
            return .invalid("Music item must have a non-empty title")
        }
        
        if title.count > 500 {
            return .invalid("Title too long (max 500 characters)")
        }
        
        // Validate artist if present
        if let artist = item["artist"] as? String {
            if artist.count > 200 {
                return .invalid("Artist name too long (max 200 characters)")
            }
        }
        
        // Validate album if present
        if let album = item["album"] as? String {
            if album.count > 200 {
                return .invalid("Album name too long (max 200 characters)")
            }
        }
        
        // Validate duration if present
        if let duration = item["duration"] as? Double {
            if duration < 0 || duration > 86400 { // 24 hours max
                return .invalid("Invalid duration")
            }
        }
        
        // Validate year if present
        if let year = item["year"] as? Int {
            let currentYear = Calendar.current.component(.year, from: Date())
            if year < 1900 || year > currentYear + 10 {
                return .invalid("Invalid year")
            }
        }
        
        return .valid
    }
    
    /// Validate playlist data
    public static func validatePlaylist(_ playlist: [String: Any]) -> DataValidator.ValidationResult {
        guard let name = playlist["name"] as? String, !name.isEmpty else {
            return .invalid("Playlist must have a non-empty name")
        }
        
        if name.count > 100 {
            return .invalid("Playlist name too long (max 100 characters)")
        }
        
        // Check for invalid characters in playlist name
        let invalidChars = CharacterSet(charactersIn: "/\\<>:\"|?*")
        if name.rangeOfCharacter(from: invalidChars) != nil {
            return .invalid("Playlist name contains invalid characters")
        }
        
        // Validate description if present
        if let description = playlist["description"] as? String {
            if description.count > 1000 {
                return .invalid("Playlist description too long (max 1000 characters)")
            }
        }
        
        return .valid
    }
}

/// Schema validation for structured data
public class SchemaValidator {
    
    public struct Field {
        public let name: String
        public let type: FieldType
        public let required: Bool
        public let constraints: [Constraint]
        
        public init(name: String, type: FieldType, required: Bool = false, constraints: [Constraint] = []) {
            self.name = name
            self.type = type
            self.required = required
            self.constraints = constraints
        }
    }
    
    public enum FieldType {
        case string
        case integer
        case double
        case boolean
        case array
        case object
    }
    
    public enum Constraint {
        case minLength(Int)
        case maxLength(Int)
        case minValue(Double)
        case maxValue(Double)
        case pattern(String)
        case oneOf([String])
    }
    
    public struct Schema {
        public let fields: [Field]
        
        public init(fields: [Field]) {
            self.fields = fields
        }
    }
    
    /// Validate data against schema
    public static func validate(_ data: [String: Any], against schema: Schema) -> DataValidator.ValidationResult {
        for field in schema.fields {
            // Check required fields
            if field.required && data[field.name] == nil {
                return .invalid("Required field '\(field.name)' is missing")
            }
            
            // Validate field if present
            if let value = data[field.name] {
                let result = validateField(value, field: field)
                if !result.isValid {
                    return result
                }
            }
        }
        
        return .valid
    }
    
    private static func validateField(_ value: Any, field: Field) -> DataValidator.ValidationResult {
        // Type validation
        switch field.type {
        case .string:
            guard let stringValue = value as? String else {
                return .invalid("Field '\(field.name)' must be a string")
            }
            return validateConstraints(stringValue, field: field)
            
        case .integer:
            guard let intValue = value as? Int else {
                return .invalid("Field '\(field.name)' must be an integer")
            }
            return validateConstraints(Double(intValue), field: field)
            
        case .double:
            guard let doubleValue = value as? Double else {
                return .invalid("Field '\(field.name)' must be a number")
            }
            return validateConstraints(doubleValue, field: field)
            
        case .boolean:
            guard value is Bool else {
                return .invalid("Field '\(field.name)' must be a boolean")
            }
            return .valid
            
        case .array:
            guard value is [Any] else {
                return .invalid("Field '\(field.name)' must be an array")
            }
            return .valid
            
        case .object:
            guard value is [String: Any] else {
                return .invalid("Field '\(field.name)' must be an object")
            }
            return .valid
        }
    }
    
    private static func validateConstraints(_ value: String, field: Field) -> DataValidator.ValidationResult {
        for constraint in field.constraints {
            switch constraint {
            case .minLength(let min):
                if value.count < min {
                    return .invalid("Field '\(field.name)' must be at least \(min) characters")
                }
            case .maxLength(let max):
                if value.count > max {
                    return .invalid("Field '\(field.name)' must be at most \(max) characters")
                }
            case .pattern(let pattern):
                let regex = try? NSRegularExpression(pattern: pattern)
                let range = NSRange(location: 0, length: value.count)
                if regex?.firstMatch(in: value, range: range) == nil {
                    return .invalid("Field '\(field.name)' does not match required pattern")
                }
            case .oneOf(let values):
                if !values.contains(value) {
                    return .invalid("Field '\(field.name)' must be one of: \(values.joined(separator: ", "))")
                }
            default:
                break
            }
        }
        return .valid
    }
    
    private static func validateConstraints(_ value: Double, field: Field) -> DataValidator.ValidationResult {
        for constraint in field.constraints {
            switch constraint {
            case .minValue(let min):
                if value < min {
                    return .invalid("Field '\(field.name)' must be at least \(min)")
                }
            case .maxValue(let max):
                if value > max {
                    return .invalid("Field '\(field.name)' must be at most \(max)")
                }
            default:
                break
            }
        }
        return .valid
    }
}
