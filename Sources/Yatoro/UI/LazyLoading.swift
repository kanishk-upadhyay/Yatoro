import Foundation

/// Lazy loading utility for efficient resource management
public class LazyLoader<T> {
    private var _value: T?
    private let initializer: () -> T
    private let dispatchQueue = DispatchQueue(label: "LazyLoader", qos: .utility)

    public init(initializer: @escaping () -> T) {
        self.initializer = initializer
    }

    public var value: T {
        if let existingValue = _value {
            return existingValue
        }

        return dispatchQueue.sync {
            if let existingValue = _value {
                return existingValue
            }

            let newValue = initializer()
            _value = newValue
            return newValue
        }
    }

    public func reset() {
        dispatchQueue.sync {
            _value = nil
        }
    }

}

/// Lazy list implementation for large collections
public class LazyList<T> {
    private var loadedItems: [Int: T] = [:]
    private let pageSize: Int
    private let totalCount: Int
    private let loader: (Int, Int) -> [T] /// offset, limit

    public init(totalCount: Int, pageSize: Int = 50, loader: @escaping (Int, Int) -> [T]) {
        self.totalCount = totalCount
        self.pageSize = pageSize
        self.loader = loader
    }

    public func item(at index: Int) -> T? {
        guard index >= 0 && index < totalCount else { return nil }

        if let existing = loadedItems[index] {
            return existing
        }

        /// Load the page containing this index
        let pageStart = (index / pageSize) * pageSize
        let items = loader(pageStart, pageSize)

        /// Cache loaded items
        for (offset, item) in items.enumerated() {
            loadedItems[pageStart + offset] = item
        }

        return loadedItems[index]
    }

    public func preloadRange(_ range: Range<Int>) {
        for index in range {
            _ = item(at: index)
        }
    }

    public var count: Int {
        return totalCount
    }

}

/// Lazy image/artwork loading system
public class LazyImageLoader {
    private var imageCache: [String: Data] = [:]
    private let cacheQueue = DispatchQueue(label: "ImageCache", qos: .utility)
    private let maxCacheSize = 50 /// Maximum number of images to cache

    public init() {}

    public func loadImage(from url: URL) async -> Data? {
        let urlString = url.absoluteString

        /// Check cache first
        if let cachedData = getCachedImage(urlString) {
            return cachedData
        }

        /// Load from network
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            cacheImage(data, for: urlString)
            return data
        } catch {
            return nil
        }
    }

    private func getCachedImage(_ url: String) -> Data? {
        return cacheQueue.sync {
            return imageCache[url]
        }
    }

    private func cacheImage(_ data: Data, for url: String) {
        cacheQueue.sync {
            /// Implement LRU-like behavior
            if imageCache.count >= maxCacheSize {
                /// Remove oldest entry (simplified)
                if let firstKey = imageCache.keys.first {
                    imageCache.removeValue(forKey: firstKey)
                }
            }

            imageCache[url] = data
        }
    }

    public func clearCache() {
        cacheQueue.sync {
            imageCache.removeAll()
        }
    }

}
