import MusicKit
import Testing

@testable import yatoro

/// Tests for the music player functionality
struct MusicPlayerTests {

    // MARK: - Player Instance Tests

    @Test func playerExists() async throws {
        // Test that the Player singleton exists
        let player = await Player.shared
        #expect(type(of: player) == AudioPlayerManager.self)
    }

    // MARK: - Player State Tests

    @Test func playerInitialState() async throws {
        // Test initial player state
        let player = await Player.shared
        #expect(player.nowPlaying == nil)
    }

}
