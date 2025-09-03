import Foundation

/// Async utilities for better concurrency handling  
public enum AsyncUtilities {
    
    /// Execute multiple async operations concurrently and return when all complete
    public static func concurrent<T: Sendable>(_ operations: [@Sendable () async -> T]) async -> [T] {
        return await withTaskGroup(of: T.self) { group in
            for operation in operations {
                group.addTask {
                    await operation()
                }
            }
            
            var results: [T] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }
    
    /// Execute operations with timeout
    public static func withTimeout<T: Sendable>(
        seconds: Double,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw YatoroError.commandNotFound("Operation timed out after \(seconds) seconds")
            }
            
            guard let result = try await group.next() else {
                throw YatoroError.invalidArguments("No result returned")
            }
            group.cancelAll()
            return result
        }
    }
}

/// Thread-safe value holder
private actor CurrentValueActor<T> {
    private var value: T
    
    init(_ initialValue: T) {
        self.value = initialValue
    }
    
    func setValue(_ newValue: T) {
        if let task = value as? Task<Void, Error> {
            task.cancel()
        }
        value = newValue
    }
    
    func getValue() -> T {
        return value
    }
}

/// Basic artwork loader
public actor BasicArtworkLoader {
    private let urlSession: URLSession
    
    public init() {
        self.urlSession = URLSession.shared
    }
    
    public func loadArtwork(from url: URL) async throws -> Data {
        let urlString = url.absoluteString
        
        // Check cache first
        let cachedData = await MainActor.run {
            ArtworkCache.shared.getCachedArtwork(urlString)?.data
        }
        if let cachedData = cachedData {
            return cachedData
        }
        
        // Load from network
        let (data, _) = try await urlSession.data(from: url)
        
        // Cache result
        let processedArtwork = ProcessedArtwork(
            data: data,
            processedAt: Date(),
            size: CGSize(width: 300, height: 300)
        )
        
        await MainActor.run {
            ArtworkCache.shared.cacheArtwork(urlString, artwork: processedArtwork)
        }
        return data
    }
    
    public func preloadArtworks(urls: [URL]) async {
        let loadOperations: [@Sendable () async -> Void] = urls.map { url in
            { [weak self] in
                _ = try? await self?.loadArtwork(from: url)
            } as @Sendable () async -> Void
        }
        
        // Execute all loads concurrently
        _ = await AsyncUtilities.concurrent(loadOperations)
    }
}
