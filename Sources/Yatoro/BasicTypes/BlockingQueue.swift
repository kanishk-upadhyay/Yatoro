import Foundation

/// Actor-based blocking queue implementation for thread-safe operations
public actor BlockingQueue<T: Sendable> {
    private var queue = [T]()
    private var continuations: [CheckedContinuation<T, Never>] = []

    public init() {}

    /// Enqueue an element, immediately resolving waiting dequeuers if any
    public func enqueue(_ element: T) {
        if !continuations.isEmpty {
            let continuation = continuations.removeFirst()
            continuation.resume(returning: element)
        } else {
            queue.append(element)
        }
    }

    /// Dequeue an element, blocking until one is available
    public func dequeue() async -> T {
        if !queue.isEmpty {
            return queue.removeFirst()
        } else {
            return await withCheckedContinuation {
                (continuation: CheckedContinuation<T, Never>) in
                continuations.append(continuation)
            }
        }
    }
}
