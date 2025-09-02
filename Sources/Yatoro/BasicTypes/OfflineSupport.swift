import Foundation

/// Offline support manager for Yatoro
public class OfflineManager {
    public static let shared = OfflineManager()
    
    private var isOfflineMode = false
    private var cachedData: [String: Any] = [:]
    private var offlineQueue: [OfflineAction] = []
    
    private let offlineDataPath: URL
    private let userDefaults = UserDefaults.standard
    
    private init() {
        // Create offline data directory
        let documentsPath = FileManager.default.urls(for: .documentsDirectory, 
                                                   in: .userDomainMask).first!
        offlineDataPath = documentsPath.appendingPathComponent("YatoroOfflineData")
        
        try? FileManager.default.createDirectory(at: offlineDataPath, 
                                               withIntermediateDirectories: true)
        
        loadOfflineData()
        checkConnectivity()
    }
    
    /// Check network connectivity
    private func checkConnectivity() {
        // In a real implementation, you'd use Network framework
        // For now, we'll simulate connectivity check
        let hasConnection = true // Placeholder
        setOfflineMode(!hasConnection)
    }
    
    /// Set offline mode state
    public func setOfflineMode(_ offline: Bool) {
        let wasOffline = isOfflineMode
        isOfflineMode = offline
        
        if wasOffline && !offline {
            // Coming back online - sync queued actions
            syncQueuedActions()
        }
        
        // Notify observers
        NotificationCenter.default.post(
            name: .offlineModeChanged,
            object: nil,
            userInfo: ["isOffline": offline]
        )
    }
    
    /// Check if currently in offline mode
    public var isOffline: Bool {
        return isOfflineMode
    }
    
    /// Cache data for offline use
    public func cacheData<T: Codable>(_ data: T, for key: String) {
        cachedData[key] = data
        saveOfflineData()
    }
    
    /// Retrieve cached data
    public func getCachedData<T: Codable>(for key: String, type: T.Type) -> T? {
        return cachedData[key] as? T
    }
    
    /// Queue action for when back online
    public func queueAction(_ action: OfflineAction) {
        offlineQueue.append(action)
        saveOfflineData()
    }
    
    /// Sync queued actions when back online
    private func syncQueuedActions() {
        let actionsToSync = offlineQueue
        offlineQueue.removeAll()
        
        for action in actionsToSync {
            Task {
                await executeAction(action)
            }
        }
        
        saveOfflineData()
    }
    
    /// Execute a queued action
    private func executeAction(_ action: OfflineAction) async {
        // Implementation would depend on action type
        print("Executing offline action: \(action.type)")
    }
    
    /// Save offline data to disk
    private func saveOfflineData() {
        let offlineData = OfflineData(
            cachedData: cachedData,
            queuedActions: offlineQueue
        )
        
        if let encoded = try? JSONEncoder().encode(offlineData) {
            let filePath = offlineDataPath.appendingPathComponent("offline.json")
            try? encoded.write(to: filePath)
        }
    }
    
    /// Load offline data from disk
    private func loadOfflineData() {
        let filePath = offlineDataPath.appendingPathComponent("offline.json")
        
        guard let data = try? Data(contentsOf: filePath),
              let offlineData = try? JSONDecoder().decode(OfflineData.self, from: data) else {
            return
        }
        
        cachedData = offlineData.cachedData
        offlineQueue = offlineData.queuedActions
    }
    
    /// Clear all offline data
    public func clearOfflineData() {
        cachedData.removeAll()
        offlineQueue.removeAll()
        saveOfflineData()
    }
    
    /// Get offline data size
    public func getOfflineDataSize() -> Int64 {
        let filePath = offlineDataPath.appendingPathComponent("offline.json")
        
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: filePath.path) else {
            return 0
        }
        
        return attributes[.size] as? Int64 ?? 0
    }
}

/// Offline action to be executed when back online
public struct OfflineAction: Codable {
    public let id: String
    public let type: ActionType
    public let parameters: [String: String]
    public let timestamp: Date
    
    public enum ActionType: String, Codable {
        case addToPlaylist
        case removeFromPlaylist
        case updateRating
        case syncLibrary
        case uploadLog
    }
    
    public init(type: ActionType, parameters: [String: String] = [:]) {
        self.id = UUID().uuidString
        self.type = type
        self.parameters = parameters
        self.timestamp = Date()
    }
}

/// Offline data structure
private struct OfflineData: Codable {
    let cachedData: [String: CodableValue]
    let queuedActions: [OfflineAction]
    
    init(cachedData: [String: Any], queuedActions: [OfflineAction]) {
        self.cachedData = cachedData.compactMapValues { CodableValue($0) }
        self.queuedActions = queuedActions
    }
}

/// Wrapper for Any type to make it Codable
private struct CodableValue: Codable {
    let value: Any
    
    init?(_ value: Any) {
        // Only support basic types for simplicity
        guard value is String || value is Int || value is Double || value is Bool else {
            return nil
        }
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else {
            throw DecodingError.typeMismatch(Any.self, DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unsupported type"
            ))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else {
            throw EncodingError.invalidValue(value, EncodingError.Context(
                codingPath: encoder.codingPath,
                debugDescription: "Unsupported type"
            ))
        }
    }
}

/// Notification names
extension Notification.Name {
    static let offlineModeChanged = Notification.Name("OfflineModeChanged")
}

/// Offline-capable data source
public protocol OfflineDataSource {
    associatedtype DataType: Codable
    
    func loadFromCache() -> DataType?
    func saveToCache(_ data: DataType)
    func loadFromNetwork() async throws -> DataType
    func syncIfNeeded() async
}

/// Generic offline data source implementation
public class GenericOfflineDataSource<T: Codable>: OfflineDataSource {
    public typealias DataType = T
    
    private let cacheKey: String
    private let networkLoader: () async throws -> T
    
    public init(cacheKey: String, networkLoader: @escaping () async throws -> T) {
        self.cacheKey = cacheKey
        self.networkLoader = networkLoader
    }
    
    public func loadFromCache() -> T? {
        return OfflineManager.shared.getCachedData(for: cacheKey, type: T.self)
    }
    
    public func saveToCache(_ data: T) {
        OfflineManager.shared.cacheData(data, for: cacheKey)
    }
    
    public func loadFromNetwork() async throws -> T {
        return try await networkLoader()
    }
    
    public func syncIfNeeded() async {
        if !OfflineManager.shared.isOffline {
            do {
                let freshData = try await loadFromNetwork()
                saveToCache(freshData)
            } catch {
                // Log error but don't throw - use cached data if available
                print("Failed to sync data: \(error)")
            }
        }
    }
}
