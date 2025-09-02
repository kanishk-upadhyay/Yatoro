import Foundation

/// Simple error types for Yatoro application
public enum YatoroError: Error, LocalizedError {
    case commandNotFound(String)
    case invalidArguments(String)
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .commandNotFound(let command):
            return "Command '\(command)' not found"
        case .invalidArguments(let details):
            return "Invalid arguments: \(details)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}