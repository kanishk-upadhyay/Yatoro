import Foundation
import CoreGraphics

// MARK: - CacheManager

/// Generic cache entry with expiration
fileprivate struct CacheEntry<T> {
    let value: T
    let expirationTime: Date
    
    var isExpired: Bool {
        Date() > expirationTime
    }
}

/// Generic LRU cache with TTL support
public class LRUCache<Key: Hashable, Value> {
    private let capacity: Int
    private let defaultTTL: TimeInterval
    
    class Node {
        let key: Key
        fileprivate var value: CacheEntry<Value>
        var prev: Node?
        var next: Node?
        
        fileprivate init(key: Key, value: CacheEntry<Value>) {
            self.key = key
            self.value = value
        }
    }
    
    private var cache: [Key: Node] = [:]
    private var head: Node?
    private var tail: Node?
    
    public init(capacity: Int = 100, defaultTTL: TimeInterval = 300) {
        self.capacity = capacity
        self.defaultTTL = defaultTTL
    }
    
    public func get(_ key: Key) -> Value? {
        guard let node = cache[key], !node.value.isExpired else {
            if let node = cache[key] {
                removeNode(node)
                cache.removeValue(forKey: key)
            }
            return nil
        }
        
        moveToFront(node)
        return node.value.value
    }
    
    public func set(_ key: Key, value: Value, ttl: TimeInterval? = nil) {
        let actualTTL = ttl ?? defaultTTL
        let expirationTime = Date().addingTimeInterval(actualTTL)
        let entry = CacheEntry(value: value, expirationTime: expirationTime)
        
        if let existingNode = cache[key] {
            existingNode.value = entry
            moveToFront(existingNode)
        } else {
            let newNode = Node(key: key, value: entry)
            cache[key] = newNode
            addToFront(newNode)
            
            if cache.count > capacity {
                evictLeastRecentlyUsed()
            }
        }
    }
    
    public func remove(_ key: Key) {
        guard let node = cache[key] else { return }
        removeNode(node)
        cache.removeValue(forKey: key)
    }
    
    public func clear() {
        cache.removeAll()
        head = nil
        tail = nil
    }
    
    public var count: Int {
        return cache.count
    }
    
    private func addToFront(_ node: Node) {
        node.prev = nil
        node.next = head
        head?.prev = node
        head = node
        
        if tail == nil {
            tail = node
        }
    }
    
    private func removeNode(_ node: Node) {
        if node.prev != nil {
            node.prev?.next = node.next
        } else {
            head = node.next
        }
        
        if node.next != nil {
            node.next?.prev = node.prev
        } else {
            tail = node.prev
        }
    }
    
    private func moveToFront(_ node: Node) {
        removeNode(node)
        addToFront(node)
    }
    
    private func evictLeastRecentlyUsed() {
        guard let tail = tail else { return }
        removeNode(tail)
        cache.removeValue(forKey: tail.key)
    }
}

// MARK: - Enhanced Cache Features (ported from SimpleCacheManager and CacheManagerClean)

extension CacheManager {
    /// Simple cache implementation for basic key-value storage
    public class SimpleCache<Key: Hashable, Value> {
        private var storage: [Key: Value] = [:]
        private let maxSize: Int
        private let queue = DispatchQueue(label: "SimpleCache", attributes: .concurrent)
        
        public init(maxSize: Int = 100) {
            self.maxSize = maxSize
        }
        
        public func set(_ value: Value, forKey key: Key) {
            queue.async(flags: .barrier) {
                if self.storage.count >= self.maxSize {
                    // Remove oldest entry (simple FIFO)
                    if let firstKey = self.storage.keys.first {
                        self.storage.removeValue(forKey: firstKey)
                    }
                }
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
    }
    
    /// Cache entry with timestamp for expiration
    public struct CacheEntry<T> {
        let value: T
        let timestamp: Date
        let ttl: TimeInterval
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }
    }
    
    /// LRU Cache implementation for more sophisticated caching needs
    public class LRUCache<Key: Hashable, Value> {
        private class Node {
            let key: Key
            var value: CacheEntry<Value>
            var prev: Node?
            var next: Node?
            
            init(key: Key, value: CacheEntry<Value>) {
                self.key = key
                self.value = value
            }
        }
        
        private var capacity: Int
        private var cache: [Key: Node] = [:]
        private var head: Node?
        private var tail: Node?
        private let queue = DispatchQueue(label: "LRUCache", attributes: .concurrent)
        
        public init(capacity: Int = 50) {
            self.capacity = capacity
        }
        
        public func get(_ key: Key) -> Value? {
            return queue.sync {
                guard let node = cache[key] else { return nil }
                
                if node.value.isExpired {
                    removeNode(node)
                    cache.removeValue(forKey: key)
                    return nil
                }
                
                moveToHead(node)
                return node.value.value
            }
        }
        
        public func set(_ key: Key, value: Value, ttl: TimeInterval = 300) {
            queue.async(flags: .barrier) {
                let entry = CacheEntry(value: value, timestamp: Date(), ttl: ttl)
                
                if let existingNode = self.cache[key] {
                    existingNode.value = entry
                    self.moveToHead(existingNode)
                } else {
                    let newNode = Node(key: key, value: entry)
                    
                    if self.cache.count >= self.capacity {
                        self.removeTail()
                    }
                    
                    self.cache[key] = newNode
                    self.addToHead(newNode)
                }
            }
        }
        
        private func addToHead(_ node: Node) {
            node.prev = nil
            node.next = head
            head?.prev = node
            head = node
            
            if tail == nil {
                tail = head
            }
        }
        
        private func removeNode(_ node: Node) {
            if node.prev != nil {
                node.prev?.next = node.next
            } else {
                head = node.next
            }
            
            if node.next != nil {
                node.next?.prev = node.prev
            } else {
                tail = node.prev
            }
        }
        
        private func moveToHead(_ node: Node) {
            removeNode(node)
            addToHead(node)
        }
        
        private func removeTail() {
            if let tail = tail {
                cache.removeValue(forKey: tail.key)
                removeNode(tail)
            }
        }
    }
}

/// Search results cache
public class SearchCache {
    private let cache = LRUCache<String, [Any]>()
    
    @MainActor
    public static let shared = SearchCache()
    
    private init() {}
    
    public func cacheSearchResults(_ query: String, results: [Any]) {
        cache.set(query, value: results, ttl: 300) // 5 minutes
    }
    
    public func getCachedResults(_ query: String) -> [Any]? {
        return cache.get(query)
    }
    
    public func clearCache() {
        cache.clear()
    }
}

/// Configuration cache for themes and settings
public class ConfigurationCache {
    private let cache = LRUCache<String, Any>()
    
    @MainActor
    public static let shared = ConfigurationCache()
    
    private init() {}
    
    public func cacheConfiguration(_ key: String, value: Any) {
        cache.set(key, value: value, ttl: 3600) // 1 hour
    }
    
    public func getCachedConfiguration(_ key: String) -> Any? {
        return cache.get(key)
    }
    
    public func removeCachedConfiguration(_ key: String) {
        cache.remove(key)
    }
    
    public func clearCache() {
        cache.clear()
    }
}

/// Processed artwork data
public struct ProcessedArtwork {
    let data: Data
    let processedAt: Date
    let size: CGSize
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
    
    public func clearCache() {
        cache.clear()
    }
}
