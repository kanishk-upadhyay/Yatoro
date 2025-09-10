# Lyrics Fetching Implementation

This document describes the implementation of lyrics fetching functionality in Yatoro.

## Overview

The implementation adds the ability to fetch and display song lyrics using Apple's MusicKit framework. Users can access lyrics through both a command-line interface and visual display in the song detail page.

## Components Added

### 1. LyricsManager (`Sources/Yatoro/Music/LyricsManager.swift`)

A centralized manager for handling lyrics fetching:
- `fetchLyrics(for:)`: Fetches lyrics for a given song
- `fetchAndLogLyrics(for:)`: Fetches lyrics and logs them to the console

### 2. LyricsCommand (`Sources/Yatoro/Commands/LyricsCommand.swift`)

A command-line interface for fetching lyrics:
- `:lyrics p` or `:ly p`: Fetch lyrics for currently playing song
- `:lyrics 0` or `:ly 0`: Fetch lyrics for search result at index 0
- Uses ArgumentParser for command parsing
- Integrates with SearchManager to access search results

### 3. SongDetailPage Enhancements

Enhanced the existing `SongDetailPage` to display lyrics:
- Added `lyricsPlane` and `lyricsTitlePlane` for UI display
- Added `loadLyrics()` method to fetch lyrics during page initialization
- Added `handleLyrics()` and `updateLyricsDisplay()` for UI management
- Integrated lyrics cleanup in the `destroy()` method
- Added lyrics color styling in `updateColors()`

### 4. Command System Integration

Updated `Command.swift` to include the new lyrics command:
- Added `.lyrics` to `CommandAction` enum
- Added lyrics command to `defaultCommands` array
- Added execution handler for lyrics command

## Usage

### Command Line Interface

1. **Current Playing Song**: `:lyrics p` or `:ly p`
   - Fetches and displays lyrics for the currently playing song

2. **Search Results**: `:lyrics 0` or `:ly 0`
   - Fetches and displays lyrics for the first song in search results
   - Replace `0` with any valid search result index

### Visual Display

- Lyrics automatically load when viewing a song's detail page
- Displayed at the bottom of the song detail view
- Shows "Lyrics:" title followed by the first few lines of lyrics
- Respects UI theme colors and styling

## Technical Details

### MusicKit Integration

The implementation uses MusicKit's `Song.with([.lyrics])` method to fetch detailed song information including lyrics. This is the recommended approach for accessing lyrics on Apple platforms.

### Error Handling

- Graceful handling of network failures
- Informative logging for debugging
- Fallback behavior when lyrics are unavailable

### Memory Management

- Proper cleanup of UI planes in destroy methods
- Async/await pattern for non-blocking lyrics fetching
- MainActor annotations for UI updates

## Future Enhancements

Potential improvements that could be added:

1. **Scrollable Lyrics**: Allow scrolling through full lyrics text
2. **Lyrics Synchronization**: Time-synced lyrics display during playback
3. **Search within Lyrics**: Find specific text within lyrics
4. **Lyrics Export**: Copy lyrics to system clipboard
5. **Cache Management**: Store fetched lyrics for offline access

## Limitations

- Lyrics availability depends on Apple Music catalog
- Display area is limited to prevent UI overflow
- Network connectivity required for initial lyrics fetch
- Only works with songs available in Apple Music catalog

## Dependencies

- MusicKit framework (for lyrics fetching)
- ArgumentParser (for command parsing)
- Existing Yatoro UI framework (SwiftNotCurses)
- Existing logging infrastructure
