import Foundation
@preconcurrency import MusicKit

/// Async utilities for better concurrency handling
public struct AsyncUtilities: Sendable {
    
    /// Execute multiple async operations concurrently and return when all complete
    public static func concurrent<T: Sendable>(
        _ operations: [@Sendable () async throws -> T]
    ) async throws -> [T] {
        return try await withThrowingTaskGroup(of: T.self) { group in
            for operation in operations {
                group.addTask {
                    try await operation()
                }
            }
            
            var results: [T] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }
    
    /// Execute async operations with timeout
    public static func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw YatoroError.networkError("Operation timed out after \(seconds) seconds")
            }
            
            guard let result = try await group.next() else {
                throw YatoroError.networkError("No result from async operation")
            }
            
            group.cancelAll()
            return result
        }
    }
    
    /// Retry an async operation with exponential backoff
    public static func withRetry<T: Sendable>(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                if attempt < maxRetries - 1 {
                    let delay = baseDelay * pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? YatoroError.unknown("Retry failed without error")
    }
    
    /// Debounce async operations
    public static func debounced<T: Sendable>(
        delay: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) -> @Sendable () async throws -> T {
        let currentTask = CurrentValueActor<Task<T, Error>?>(nil)
        
        return {
            await currentTask.setValue(nil) // Cancel previous task
            
            let newTask = Task<T, Error> {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await operation()
            }
            
            await currentTask.setValue(newTask)
            return try await newTask.value
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
        if let task = value as? Task<Any, Error> {
            task.cancel()
        }
        value = newValue
    }
    
    func getValue() -> T {
        return value
    }
}

/// Basic artwork loader
public class BasicArtworkLoader: Sendable {
    private let urlSession: URLSession
    
    public init() {
        self.urlSession = URLSession.shared
    }
    
    public func loadArtwork(from url: URL) async throws -> Data {
        let urlString = url.absoluteString
        
        // This file has been consolidated into AsyncOptimizations.swift
// All functionality has been ported to the main implementation
        if let cachedArtwork = await ArtworkCache.shared.getCachedArtwork(urlString) {
            return cachedArtwork.data
        }
        
        // Load from network
        let (data, _) = try await urlSession.data(from: url)
        
        // Cache result
        let processedArtwork = ProcessedArtwork(
            data: data,
            processedAt: Date(),
            size: CGSize(width: 300, height: 300)
        )
        
        await ArtworkCache.shared.cacheArtwork(urlString, artwork: processedArtwork)
        return data
    }
    
    public func preloadArtworks(urls: [URL]) async {
        let loadOperations = urls.map { url in
            { [weak self] in
                try? await self?.loadArtwork(from: url)
            }
        }
        
        // Execute all loads concurrently
        _ = try? await AsyncUtilities.concurrent(loadOperations)
    }
}
