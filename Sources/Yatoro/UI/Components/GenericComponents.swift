import Foundation
import MusicKit
import SwiftNotCurses

/// Generic list page for displaying music items
@MainActor
public class GenericListPage<T: MusicItem>: DestroyablePage {
    
    private let items: [T]
    private let renderer: any ItemRenderer<T>
    private let state: PageState
    private let plane: Plane
    private let borderPlane: Plane
    private let titlePlane: Plane
    private let contentPlane: Plane
    
    private var currentSelection: Int = 0
    private var scrollOffset: Int = 0
    
    public init?(
        items: [T],
        renderer: any ItemRenderer<T>,
        state: PageState,
        stdPlane: Plane,
        title: String
    ) {
        self.items = items
        self.renderer = renderer
        self.state = state
        
        guard let plane = Plane(in: stdPlane, state: state, debugID: "GENERIC_LIST") else {
            return nil
        }
        self.plane = plane
        
        guard let borderPlane = Plane(in: plane, state: .init(absX: 0, absY: 0, width: state.width, height: state.height), debugID: "GENERIC_LIST_BORDER") else {
            return nil
        }
        self.borderPlane = borderPlane
        
        guard let titlePlane = Plane(in: plane, state: .init(absX: 2, absY: 0, width: state.width - 4, height: 1), debugID: "GENERIC_LIST_TITLE") else {
            return nil
        }
        self.titlePlane = titlePlane
        
        guard let contentPlane = Plane(in: plane, state: .init(absX: 1, absY: 2, width: state.width - 2, height: state.height - 3), debugID: "GENERIC_LIST_CONTENT") else {
            return nil
        }
        self.contentPlane = contentPlane
        
        updateColors()
        titlePlane.putString(title, at: (0, 0))
        borderPlane.windowBorder(width: state.width, height: state.height)
    }
    
    public func updateColors() {
        let theme = Theme.shared.search // Use search theme as default
        borderPlane.setColorPair(theme.border)
        titlePlane.setColorPair(theme.pageName)
        contentPlane.setColorPair(theme.page)
        plane.setColorPair(theme.page)
    }
    
    public func render() async {
        contentPlane.erase()
        
        let visibleHeight = Int(contentPlane.height)
        let visibleItems = items.dropFirst(scrollOffset).prefix(visibleHeight)
        
        for (index, item) in visibleItems.enumerated() {
            let globalIndex = scrollOffset + index
            let isSelected = globalIndex == currentSelection
            
            let renderedText = renderer.render(item, isSelected: isSelected, width: Int(contentPlane.width))
            contentPlane.putString(renderedText, at: (0, Int32(index)))
        }
    }
    
    public func selectNext() {
        if currentSelection < items.count - 1 {
            currentSelection += 1
            adjustScrollOffset()
        }
    }
    
    public func selectPrevious() {
        if currentSelection > 0 {
            currentSelection -= 1
            adjustScrollOffset()
        }
    }
    
    public func getSelectedItem() -> T? {
        guard currentSelection < items.count else { return nil }
        return items[currentSelection]
    }
    
    private func adjustScrollOffset() {
        let visibleHeight = Int(contentPlane.height)
        
        if currentSelection < scrollOffset {
            scrollOffset = currentSelection
        } else if currentSelection >= scrollOffset + visibleHeight {
            scrollOffset = currentSelection - visibleHeight + 1
        }
    }
    
    public func onResize(newPageState: PageState) async {
        // Implementation for resize handling
    }
    
    public func getMinDimensions() async -> (width: UInt32, height: UInt32) {
        return (30, 10)
    }
    
    public func getMaxDimensions() async -> (width: UInt32, height: UInt32)? {
        return nil
    }
    
    public func getPageState() async -> PageState {
        return state
    }
    
    public func destroy() async {
        contentPlane.destroy()
        titlePlane.destroy()
        borderPlane.destroy()
        plane.destroy()
    }
}

/// Generic item renderer protocol
public protocol ItemRenderer<T> {
    associatedtype T: MusicItem
    
    func render(_ item: T, isSelected: Bool, width: Int) -> String
}

/// Song item renderer
public struct SongRenderer: ItemRenderer {
    public func render(_ item: Song, isSelected: Bool, width: Int) -> String {
        let prefix = isSelected ? "► " : "  "
        let title = item.title
        let artist = item.artistName
        
        let text = "\(prefix)\(title) - \(artist)"
        return String(text.prefix(width))
    }
}

/// Album item renderer
public struct AlbumRenderer: ItemRenderer {
    public func render(_ item: Album, isSelected: Bool, width: Int) -> String {
        let prefix = isSelected ? "► " : "  "
        let title = item.title
        let artist = item.artistName
        
        let text = "\(prefix)[\(title)] by \(artist)"
        return String(text.prefix(width))
    }
}

/// Artist item renderer
public struct ArtistRenderer: ItemRenderer {
    public func render(_ item: Artist, isSelected: Bool, width: Int) -> String {
        let prefix = isSelected ? "► " : "  "
        let text = "\(prefix)♪ \(item.name)"
        return String(text.prefix(width))
    }
}

/// Playlist item renderer
public struct PlaylistRenderer: ItemRenderer {
    public func render(_ item: Playlist, isSelected: Bool, width: Int) -> String {
        let prefix = isSelected ? "► " : "  "
        let trackCount = item.tracks?.count ?? 0
        let text = "\(prefix)📋 \(item.name) (\(trackCount) tracks)"
        return String(text.prefix(width))
    }
}

/// Generic data source for paginated content
public class PaginatedDataSource<T> {
    private var allItems: [T] = []
    private let pageSize: Int
    private var currentPage: Int = 0
    
    public init(pageSize: Int = 50) {
        self.pageSize = pageSize
    }
    
    public func setItems(_ items: [T]) {
        allItems = items
        currentPage = 0
    }
    
    public func getCurrentPageItems() -> [T] {
        let startIndex = currentPage * pageSize
        let endIndex = min(startIndex + pageSize, allItems.count)
        guard startIndex < allItems.count else { return [] }
        return Array(allItems[startIndex..<endIndex])
    }
    
    public func nextPage() -> Bool {
        let maxPage = (allItems.count - 1) / pageSize
        if currentPage < maxPage {
            currentPage += 1
            return true
        }
        return false
    }
    
    public func previousPage() -> Bool {
        if currentPage > 0 {
            currentPage -= 1
            return true
        }
        return false
    }
    
    public func getCurrentPage() -> Int {
        return currentPage
    }
    
    public func getTotalPages() -> Int {
        guard !allItems.isEmpty else { return 0 }
        return (allItems.count - 1) / pageSize + 1
    }
    
    public func getTotalItems() -> Int {
        return allItems.count
    }
}

/// Generic collection utilities
public struct CollectionUtilities {
    
    /// Safe array access that returns nil instead of crashing
    public static func safeAccess<T>(_ array: [T], at index: Int) -> T? {
        guard index >= 0 && index < array.count else { return nil }
        return array[index]
    }
    
    /// Chunk array into smaller arrays
    public static func chunk<T>(_ array: [T], size: Int) -> [[T]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: array.count, by: size).map {
            Array(array[$0..<min($0 + size, array.count)])
        }
    }
    
    /// Find items matching a predicate with limit
    public static func findMatching<T>(
        in array: [T],
        matching predicate: (T) -> Bool,
        limit: Int = Int.max
    ) -> [T] {
        var results: [T] = []
        for item in array {
            if predicate(item) {
                results.append(item)
                if results.count >= limit {
                    break
                }
            }
        }
        return results
    }
    
    /// Group items by a key function
    public static func groupBy<T, K: Hashable>(
        _ array: [T],
        keySelector: (T) -> K
    ) -> [K: [T]] {
        return Dictionary(grouping: array, by: keySelector)
    }
    
    /// Remove duplicates while preserving order
    public static func removeDuplicates<T: Hashable>(_ array: [T]) -> [T] {
        var seen = Set<T>()
        return array.filter { seen.insert($0).inserted }
    }
}

/// Generic search utilities
public struct SearchUtilities {
    
    /// Simple text matching with case insensitivity
    public static func simpleMatch(_ text: String, query: String) -> Bool {
        return text.lowercased().contains(query.lowercased())
    }
    
    /// Calculate simple relevance score for search results
    public static func calculateRelevance(_ text: String, query: String) -> Double {
        let lowerText = text.lowercased()
        let lowerQuery = query.lowercased()
        
        // Exact match gets highest score
        if lowerText == lowerQuery {
            return 1.0
        }
        
        // Starts with query gets high score
        if lowerText.hasPrefix(lowerQuery) {
            return 0.9
        }
        
        // Contains query gets medium score
        if lowerText.contains(lowerQuery) {
            return 0.5
        }
        
        // Calculate word matches
        let textWords = lowerText.components(separatedBy: .whitespaces)
        let queryWords = lowerQuery.components(separatedBy: .whitespaces)
        
        let matchingWords = queryWords.filter { queryWord in
            textWords.contains { textWord in
                textWord.contains(queryWord)
            }
        }
        
        let wordMatchRatio = Double(matchingWords.count) / Double(queryWords.count)
        return wordMatchRatio * 0.3
    }
    
    /// Search music items with relevance scoring
    public static func searchMusicItems<T: MusicItem>(
        _ items: [T],
        query: String,
        textExtractor: (T) -> [String]
    ) -> [T] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        
        let scoredItems = items.compactMap { item -> (item: T, score: Double)? in
            let texts = textExtractor(item)
            let maxScore = texts.map { calculateRelevance($0, query: query) }.max() ?? 0
            return maxScore > 0 ? (item, maxScore) : nil
        }
        
        return scoredItems
            .sorted { $0.score > $1.score }
            .map { $0.item }
    }
}
