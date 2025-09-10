import MusicKit
import Logging

@MainActor
public class LyricsManager {
    
    public static let shared = LyricsManager()
    
    private init() {}
    
    /// Fetches lyrics for a given song
    public func fetchLyrics(for song: Song) async -> String? {
        do {
            let detailedSong = try await song.with([.lyrics])
            return detailedSong.lyrics
        } catch {
            await logger?.error("LyricsManager: Failed to fetch lyrics for '\(song.title)': \(error)")
            return nil
        }
    }
    
    /// Fetches and logs lyrics for a song
    public func fetchAndLogLyrics(for song: Song) async {
        if let lyrics = await fetchLyrics(for: song) {
            await logger?.info("Lyrics for '\(song.title)' by \(song.artistName):")
            await logger?.info(lyrics)
        } else {
            await logger?.info("No lyrics available for '\(song.title)' by \(song.artistName)")
        }
    }
}
