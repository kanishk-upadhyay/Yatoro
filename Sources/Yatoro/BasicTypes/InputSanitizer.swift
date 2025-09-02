import Foundation

/// Input sanitization utilities for Yatoro
public struct InputSanitizer {
    
    /// Sanitizes command input by removing potentially harmful characters
    public static func sanitizeCommand(_ input: String) -> String {
        // Remove control characters and trim whitespace
        let cleaned = input
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Limit length to prevent buffer overflow
        let maxLength = 1000
        if cleaned.count > maxLength {
            return String(cleaned.prefix(maxLength))
        }
        
        return cleaned
    }
    
    /// Sanitizes search query input
    public static func sanitizeSearchQuery(_ input: String) -> String {
        // Remove control characters and excessive whitespace
        let cleaned = input
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        
        // Limit length for search queries
        let maxLength = 500
        if cleaned.count > maxLength {
            return String(cleaned.prefix(maxLength))
        }
        
        // Remove potentially problematic characters for search
        let allowedCharacterSet = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(.punctuationCharacters)
            .subtracting(CharacterSet(charactersIn: "<>\"'&;"))
        
        return String(cleaned.unicodeScalars.filter { allowedCharacterSet.contains($0) })
    }
    
    /// Sanitizes file path input
    public static func sanitizeFilePath(_ input: String) -> String {
        // Remove control characters and trim
        let cleaned = input
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove path traversal attempts
        let pathCleaned = cleaned
            .replacingOccurrences(of: "../", with: "")
            .replacingOccurrences(of: "..\\", with: "")
            .replacingOccurrences(of: "~/", with: "")
        
        // Limit length
        let maxLength = 255
        if pathCleaned.count > maxLength {
            return String(pathCleaned.prefix(maxLength))
        }
        
        return pathCleaned
    }
    
    /// Validates and sanitizes numeric input
    public static func sanitizeNumericInput(_ input: String) -> String? {
        let cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Only allow digits, decimal point, and negative sign
        let allowedCharacterSet = CharacterSet(charactersIn: "0123456789.-")
        let filtered = String(cleaned.unicodeScalars.filter { allowedCharacterSet.contains($0) })
        
        // Validate it's a proper number
        if Double(filtered) != nil {
            return filtered
        }
        
        return nil
    }
    
    /// General purpose text sanitization
    public static func sanitizeText(_ input: String) -> String {
        // Remove control characters except newlines and tabs
        let controlCharsToRemove = CharacterSet.controlCharacters
            .subtracting(CharacterSet(charactersIn: "\n\t"))
        
        let cleaned = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .unicodeScalars
            .filter { !controlCharsToRemove.contains($0) }
        
        let result = String(String.UnicodeScalarView(cleaned))
        
        // Limit length
        let maxLength = 2000
        if result.count > maxLength {
            return String(result.prefix(maxLength))
        }
        
        return result
    }
}

/// Input validation utilities
public struct InputValidator {
    
    /// Validates command name format
    public static func validateCommandName(_ name: String) -> Bool {
        // Command names should be alphanumeric with optional underscores
        let pattern = "^[a-zA-Z][a-zA-Z0-9_]*$"
        return name.range(of: pattern, options: .regularExpression) != nil
    }
    
    /// Validates search query
    public static func validateSearchQuery(_ query: String) -> Result<String, YatoroError> {
        let sanitized = InputSanitizer.sanitizeSearchQuery(query)
        
        guard !sanitized.isEmpty else {
            return .failure(.validationError("Search query cannot be empty"))
        }
        
        guard sanitized.count >= 2 else {
            return .failure(.validationError("Search query must be at least 2 characters"))
        }
        
        return .success(sanitized)
    }
    
    /// Validates numeric range input
    public static func validateNumericRange(_ input: String, min: Double, max: Double) -> Result<Double, YatoroError> {
        guard let sanitized = InputSanitizer.sanitizeNumericInput(input),
              let value = Double(sanitized) else {
            return .failure(.validationError("Invalid numeric input: '\(input)'"))
        }
        
        guard value >= min && value <= max else {
            return .failure(.validationError("Value \(value) is outside allowed range [\(min), \(max)]"))
        }
        
        return .success(value)
    }
    
    /// Validates file path
    public static func validateFilePath(_ path: String) -> Result<String, YatoroError> {
        let sanitized = InputSanitizer.sanitizeFilePath(path)
        
        guard !sanitized.isEmpty else {
            return .failure(.validationError("File path cannot be empty"))
        }
        
        // Check for obviously invalid patterns
        let invalidPatterns = ["//", "\\\\", ".."]
        for pattern in invalidPatterns {
            if sanitized.contains(pattern) {
                return .failure(.validationError("Invalid characters in file path"))
            }
        }
        
        return .success(sanitized)
    }
}
