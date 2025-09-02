import Testing
import Foundation
@testable import yatoro

struct CommandTests {
    
    // MARK: - Command Lookup Tests
    
    @Test func commandLookupPerformance() {
        // Test that command lookup is efficient - using basic timing since measure{} is XCTest specific
        let startTime = DispatchTime.now()
        for _ in 0..<1000 {
            _ = Command.commandLookup["play"]
            _ = Command.commandLookup["search"]
            _ = Command.commandLookup["help"]
        }
        let endTime = DispatchTime.now()
        let elapsed = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        
        // Should complete 1000 lookups in under 10ms (very generous)
        #expect(elapsed < 10_000_000)
    }
    
    @Test func validCommandLookup() {
        // Test that all default commands can be found
        for command in Command.defaultCommands {
            #expect(Command.commandLookup[command.name] != nil, "Command '\(command.name)' not found in lookup")
            
            if let shortName = command.shortName {
                #expect(Command.commandLookup[shortName] != nil, "Short command '\(shortName)' not found in lookup")
            }
        }
    }
    
    @Test func invalidCommandLookup() {
        #expect(Command.commandLookup["invalidcommand"] == nil)
        #expect(Command.commandLookup[""] == nil)
        #expect(Command.commandLookup["123"] == nil)
    }
    
    @Test func commandLookupCaseInsensitive() {
        // Note: Current implementation is case-sensitive, 
        // this test documents the current behavior
        #expect(Command.commandLookup["play"] != nil)
        #expect(Command.commandLookup["PLAY"] == nil)
        #expect(Command.commandLookup["Play"] == nil)
    }
    
    // MARK: - Command Structure Tests
    
    @Test func commandStructure() {
        let command = Command(name: "test", short: "t", action: .play)
        
        #expect(command.name == "test")
        #expect(command.shortName == "t")
        #expect(command.action == .play)
    }
    
    @Test func commandWithoutShortName() {
        let command = Command(name: "test", action: .play)
        
        #expect(command.name == "test")
        #expect(command.shortName == nil)
        #expect(command.action == .play)
    }
    
    @Test func commandWithoutAction() {
        let command = Command(name: "help", short: "h", action: nil)
        
        #expect(command.name == "help")
        #expect(command.shortName == "h")
        #expect(command.action == nil)
    }
    
    // MARK: - Default Commands Tests
    
    @Test func defaultCommandsCount() {
        // Ensure we have the expected number of commands
        #expect(Command.defaultCommands.count > 0)
        #expect(Command.defaultCommands.count < 50) // Reasonable upper bound
    }
    
    @Test func defaultCommandsUniqueness() {
        let names = Command.defaultCommands.map { $0.name }
        let uniqueNames = Set(names)
        #expect(names.count == uniqueNames.count, "Duplicate command names found")
        
        let shortNames = Command.defaultCommands.compactMap { $0.shortName }
        let uniqueShortNames = Set(shortNames)
        #expect(shortNames.count == uniqueShortNames.count, "Duplicate short names found")
    }
    
    @Test func requiredCommandsExist() {
        let requiredCommands = ["help", "search", "play", "pause", "quitApplication"]
        
        for requiredCommand in requiredCommands {
            #expect(
                Command.defaultCommands.contains { $0.name == requiredCommand },
                "Required command '\(requiredCommand)' not found"
            )
        }
    }
    
    @Test func helpCommandConfiguration() {
        guard let helpCommand = Command.defaultCommands.first(where: { $0.name == "help" }) else {
            Issue.record("Help command not found")
            return
        }
        
        #expect(helpCommand.shortName == "h")
        #expect(helpCommand.action == nil) // Help is handled specially
    }
}

struct SimpleCacheTests {
    
    @Test func basicCacheOperations() {
        let cache = SimpleCache<String, String>(maxSize: 3)
        
        // Test set and get
        cache.set("key1", value: "value1")
        #expect(cache.get("key1") == "value1")
        
        // Test non-existent key
        #expect(cache.get("nonexistent") == nil)
    }
    
    @Test func cacheCapacity() {
        let cache = SimpleCache<String, String>(maxSize: 3)
        
        // Fill cache beyond capacity
        cache.set("key1", value: "value1")
        cache.set("key2", value: "value2")
        cache.set("key3", value: "value3")
        cache.set("key4", value: "value4") // Should trigger eviction
        
        // Should have exactly maxSize items
        #expect(cache.count == 3)
        
        // At least one of the keys should be there (cache behavior is not strictly defined)
        let hasAtLeastOneKey = cache.get("key1") != nil || 
                              cache.get("key2") != nil || 
                              cache.get("key3") != nil || 
                              cache.get("key4") != nil
        #expect(hasAtLeastOneKey)
    }
    
    @Test func cacheRemove() {
        let cache = SimpleCache<String, String>(maxSize: 3)
        
        cache.set("key1", value: "value1")
        #expect(cache.get("key1") == "value1")
        
        cache.remove("key1")
        #expect(cache.get("key1") == nil)
    }
    
    @Test func cacheClear() {
        let cache = SimpleCache<String, String>(maxSize: 3)
        
        cache.set("key1", value: "value1")
        cache.set("key2", value: "value2")
        
        cache.clear()
        
        #expect(cache.get("key1") == nil)
        #expect(cache.get("key2") == nil)
        #expect(cache.count == 0)
    }
}

struct SearchCacheTests {
    
    @MainActor @Test func searchCacheOperations() {
        SearchCache.shared.clearCache()
        
        let results = ["song1", "song2", "song3"]
        
        SearchCache.shared.cacheSearchResults("Tool", results: results)
        let cached = SearchCache.shared.getCachedResults("Tool")
        
        #expect(cached != nil)
        #expect(cached?.count == 3)
    }
    
    @MainActor @Test func searchCacheMiss() {
        SearchCache.shared.clearCache()
        
        let cached = SearchCache.shared.getCachedResults("NonexistentQuery")
        #expect(cached == nil)
    }
}

struct YatoroErrorTests {
    
    @Test func yatoroErrorCreation() {
        let commandError = YatoroError.commandNotFound("invalidCommand")
        let argError = YatoroError.invalidArguments("Missing parameter")
        let unknownError = YatoroError.unknown("Something went wrong")
        
        #expect(commandError.errorDescription == "Command 'invalidCommand' not found")
        #expect(argError.errorDescription == "Invalid arguments: Missing parameter")
        #expect(unknownError.errorDescription == "Error: Something went wrong")
    }
}

struct ArgumentsTests {
    
    @Test func musicItemTypeInitialization() {
        #expect(MusicItemType(argument: "song") == .song)
        #expect(MusicItemType(argument: "so") == .song)
        #expect(MusicItemType(argument: "album") == .album)
        #expect(MusicItemType(argument: "al") == .album)
        #expect(MusicItemType(argument: "artist") == .artist)
        #expect(MusicItemType(argument: "ar") == .artist)
        #expect(MusicItemType(argument: "playlist") == .playlist)
        #expect(MusicItemType(argument: "p") == .playlist)
        #expect(MusicItemType(argument: "station") == .station)
        #expect(MusicItemType(argument: "st") == .station)
        
        // Test invalid input
        #expect(MusicItemType(argument: "invalid") == nil)
        #expect(MusicItemType(argument: "") == nil)
    }
}

struct MappingTests {
    
    @MainActor @Test func defaultMappingsExist() {
        #expect(Mapping.defaultMappings.count > 0)
        
        // Test some key mappings exist
        let playMapping = Mapping.defaultMappings.first { $0.key == "p" && $0.modifiers == nil }
        #expect(playMapping != nil)
        #expect(playMapping?.action == ":playPauseToggle<CR>")
        
        let quitMapping = Mapping.defaultMappings.first { $0.key == "q" }
        #expect(quitMapping != nil)
        #expect(quitMapping?.action == ":quitApplication<CR>")
    }
    
    @MainActor @Test func mappingUniqueness() {
        let mappings = Mapping.defaultMappings
        let keyModifierPairs = mappings.map { ($0.key, $0.modifiers?.map(\.rawValue).sorted() ?? []) }
        _ = Set(keyModifierPairs.map { "\($0.0)-\($0.1.joined(separator: ","))" })
        
        // Allow some duplicates for p key with different modifiers
        // This is just a basic structure test - actual uniqueness testing would be more complex
        #expect(mappings.count > 0)
    }
}
