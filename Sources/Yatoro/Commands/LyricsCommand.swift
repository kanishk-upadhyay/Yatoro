import MusicKit
import ArgumentParser
import Logging

struct LyricsCommand: AsyncParsableCommand {
    
    @Argument(help: "Target to fetch lyrics for: 'p' for current playing song, or index number for search result")
    var target: String = "p"
    
    static func execute(arguments: [String]) async {
        do {
            let command = try LyricsCommand.parse(arguments)
            await command.run()
        } catch {
            await logger?.error("Failed to parse lyrics command: \(error)")
        }
    }
    
    @MainActor
    func run() async {
        if target == "p" {
            // Fetch lyrics for currently playing song
            await fetchLyricsForCurrentSong()
        } else if let index = Int(target) {
            // Fetch lyrics for search result at index
            await fetchLyricsForSearchResult(at: index)
        } else {
            await logger?.error("Invalid lyrics command target: \(target)")
        }
    }
    
    @MainActor
    private func fetchLyricsForCurrentSong() async {
        guard let currentSong = Player.shared.nowPlaying else {
            await logger?.info("No song is currently playing")
            return
        }
        
        await fetchAndDisplayLyrics(for: currentSong)
    }
    
    @MainActor
    private func fetchLyricsForSearchResult(at index: Int) async {
        guard let searchResult = SearchManager.shared.lastSearchResult else {
            await logger?.info("No search results available")
            return
        }
        
        // Handle different search result types
        switch searchResult.result {
        case .catalogSearch(let result):
            if case .songs(let songs) = result.topResult {
                if index < songs.count {
                    let song = songs[index]
                    await fetchAndDisplayLyrics(for: song)
                } else {
                    await logger?.error("Index \(index) out of range for search results")
                }
            } else {
                await logger?.info("Current search results are not songs")
            }
        case .librarySearch(let result):
            if case .songs(let songs) = result.topResult {
                if index < songs.count {
                    let song = songs[index]
                    await fetchAndDisplayLyrics(for: song)
                } else {
                    await logger?.error("Index \(index) out of range for search results")
                }
            } else {
                await logger?.info("Current search results are not songs")
            }
        }
    }
    
    @MainActor
    private func fetchAndDisplayLyrics(for song: Song) async {
        await LyricsManager.shared.fetchAndLogLyrics(for: song)
    }
}
