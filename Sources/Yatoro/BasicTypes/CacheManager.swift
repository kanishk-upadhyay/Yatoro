import Foundation

/// Generic cache entry with expiration
private struct CacheEntry<T> {
    let value: T
    let expirationTime: Date
    
    var isExpired: Bool {
        Date() > expirationTime
    }
}

/// Generic LRU cache with TTL support
public class LRUCache<Key: Hashable & Sendable, Value>: @unchecked Sendable {
    private let capacity: Int
    private let defaultTTL: TimeInterval
    private var cache: [Key: CacheEntry<Value>] = [:]
    private let queue = DispatchQueue(label: "LRUCache", attributes: .concurrent)
    
    public init(capacity: Int = 100, defaultTTL: TimeInterval = 3600) {
        self.capacity = capacity
        self.defaultTTL = defaultTTL
    }
    
    public func set(_ key: Key, value: Value, ttl: TimeInterval? = nil) {
        let expirationTime = Date().addingTimeInterval(ttl ?? defaultTTL)
        let entry = CacheEntry(value: value, expirationTime: expirationTime)
        
        queue.async(flags: .barrier) {
            self.cache[key] = entry
            self.evictExpired()
            if self.cache.count > self.capacity {
                self.evictOldest()
            }
        }
    }
    
    public func get(_ key: Key) -> Value? {
        return queue.sync {
            guard let entry = cache[key], !entry.isExpired else {
                cache.removeValue(forKey: key)
                return nil
            }
            return entry.value
        }
    }
    
    private func evictExpired() {
        cache = cache.filter { !$0.value.isExpired }
    }
    
    private func evictOldest() {
        guard cache.count > capacity else { return }
        let oldestKey = cache.min { $0.value.expirationTime < $1.value.expirationTime }?.key
        if let key = oldestKey {
            cache.removeValue(forKey: key)
        }
    }
}

/// Simple cache implementation for basic key-value storage  
public class SimpleCache<Key: Hashable & Sendable, Value>: @unchecked Sendable {
    private var storage: [Key: Value] = [:]
    private let queue = DispatchQueue(label: "SimpleCache", attributes: .concurrent)
    
    public init() {}
    
    public func set(_ key: Key, value: Value) {
        queue.async(flags: .barrier) {
            self.storage[key] = value
        }
    }
    
    public func get(_ key: Key) -> Value? {
        return queue.sync {
            return storage[key]
        }
    }
    
    public func remove(_ key: Key) {
        queue.async(flags: .barrier) {
            self.storage.removeValue(forKey: key)
        }
    }
    
    public func clear() {
        queue.async(flags: .barrier) {
            self.storage.removeAll()
        }
    }
    
    public var count: Int {
        return queue.sync {
            return storage.count
        }
    }
}

/// Search results cache
public class SearchCache {
    private let cache = LRUCache<String, [Any]>()
    
    @MainActor
    public static let shared = SearchCache()
    
    private init() {}
    
    public func cacheResults(_ key: String, results: [Any]) {
        cache.set(key, value: results, ttl: 600) // 10 minutes
    }
    
    public func getCachedResults(_ key: String) -> [Any]? {
        return cache.get(key)
    }
    
    public func clearCache() {
        // Implementation for clearing would go here
    }
}

/// Configuration cache for themes and settings
public class ConfigurationCache {
    private let cache = LRUCache<String, Any>()
    
    @MainActor
    public static let shared = ConfigurationCache()
    
    private init() {}
    
    public func cacheConfig(_ key: String, value: Any) {
        cache.set(key, value: value, ttl: 3600) // 1 hour
    }
    
    public func getCachedConfig(_ key: String) -> Any? {
        return cache.get(key)
    }
}

/// Processed artwork data
public struct ProcessedArtwork: Sendable {
    let data: Data
    let processedAt: Date
    let size: CGSize?
}

/// Artwork processing cache  
public class ArtworkCache {
    private let cache = LRUCache<String, ProcessedArtwork>()
    
    @MainActor
    public static let shared = ArtworkCache()
    
    private init() {}
    
    public func cacheArtwork(_ url: String, artwork: ProcessedArtwork) {
        cache.set(url, value: artwork, ttl: 1800) // 30 minutes
    }
    
    public func getCachedArtwork(_ url: String) -> ProcessedArtwork? {
        return cache.get(url)
    }
}
