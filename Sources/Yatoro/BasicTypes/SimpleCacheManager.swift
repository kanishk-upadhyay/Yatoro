import Foundation
import CoreGraphics

/// Simple cache implementation
public class SimpleCache<Key: Hashable, Value> {
    private var cache: [Key: Value] = [:]
    private let maxSize: Int
    
    public init(maxSize: Int = 50) {
        self.maxSize = maxSize
    }
    
    public func get(_ key: Key) -> Value? {
        return cache[key]
    }
    
    public func set(_ key: Key, value: Value) {
        cache[key] = value
        
        // Simple eviction: if we exceed max size, remove some random entries
        if cache.count > maxSize {
            let keysToRemove = Array(cache.keys.prefix(cache.count - maxSize))
            for key in keysToRemove {
                cache.removeValue(forKey: key)
            }
        }
    }
    
    public func remove(_ key: Key) {
        cache.removeValue(forKey: key)
    }
    
    public func clear() {
        cache.removeAll()
    }
    
    public var count: Int {
        return cache.count
    }
}

/// Simple search results cache
public class SearchCache {
    private let cache = SimpleCache<String, [Any]>()
    
    @MainActor
    public static let shared = SearchCache()
    
    private init() {}
    
    public func cacheSearchResults(_ query: String, results: [Any]) {
        cache.set(query, value: results)
    }
    
    public func getCachedResults(_ query: String) -> [Any]? {
        return cache.get(query)
    }
    
    public func clearCache() {
        cache.clear()
    }
}

/// Simple artwork cache
public struct ProcessedArtwork {
    let data: Data
    let processedAt: Date
    let size: CGSize
}

public class ArtworkCache {
    private let cache = SimpleCache<String, ProcessedArtwork>()
    
    @MainActor
    public static let shared = ArtworkCache()
    
    private init() {}
    
    public func cacheArtwork(_ url: String, artwork: ProcessedArtwork) {
        cache.set(url, value: artwork)
    }
    
    public func getCachedArtwork(_ url: String) -> ProcessedArtwork? {
        return cache.get(url)
    }
    
    public func clearCache() {
        cache.clear()
    }
}
