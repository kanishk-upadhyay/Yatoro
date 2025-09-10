import SwiftNotCurses
import MusicKit

@MainActor
public class SongDetailPage: DestroyablePage {

    private let maxLyricsDisplayHeight: UInt32 = 6

    private var state: PageState

    private let songDescription: SongDescriptionResult

    private var plane: Plane

    private var borderPlane: Plane

    private var artworkPlane: Plane
    private var artworkVisual: Visual?

    private var songTitlePlane: Plane  // Name of the song
    private var artistsTitlePlane: Plane?  // "Artists:"
    private var artistsIndicesPlane: Plane?  // Indexes of artists

    private var artistItemPages: [ArtistItemPage?]
    private var albumItemPage: AlbumItemPage?
    private var albumTitlePlane: Plane?  // "Album:"
    private var albumIndexPlane: Plane?

    // Lyrics display
    private var lyricsPlane: Plane?
    private var lyricsTitlePlane: Plane?
    private var lyrics: String?

    private var maxItemsDisplayed: Int {
        Int(state.height - 8) / 5
    }

    // TODO: Maybe consider displaying lyrics if they're present, idk

    public init?(
        in stdPlane: Plane,
        state: PageState,
        songDescription: SongDescriptionResult
    ) {
        self.state = state
        self.songDescription = songDescription

        guard
            let plane = Plane(
                in: stdPlane,
                state: state,
                debugID: "SDP"
            )
        else {
            return nil
        }
        self.plane = plane

        guard
            let artworkPlane = Plane(
                in: plane,
                state: .init(
                    absX: 0,
                    absY: 0,
                    width: 1,
                    height: 1
                ),
                debugID: "SDPAP"
            )
        else {
            return nil
        }
        self.artworkPlane = artworkPlane

        guard
            let borderPlane = Plane(
                in: plane,
                state: .init(
                    absX: 0,
                    absY: 0,
                    width: state.width,
                    height: state.height
                ),
                debugID: "SDBP"
            )
        else {
            return nil
        }
        self.borderPlane = borderPlane

        let title = songDescription.song.title
        guard
            let songTitlePlane = Plane(
                in: plane,
                state: .init(
                    absX: 4,
                    absY: 2,
                    width: UInt32(title.count),
                    height: 1
                ),
                debugID: "SDTP"
            )
        else {
            return nil
        }
        self.songTitlePlane = songTitlePlane

        let oneThirdWidth = Int32(state.width) / 3

        self.artistsTitlePlane = Plane(
            in: plane,
            state: .init(
                absX: oneThirdWidth * 2 + 2,
                absY: 2,
                width: 8,
                height: 1
            ),
            debugID: "SDPARTP"
        )

        self.albumTitlePlane = Plane(
            in: plane,
            state: .init(
                absX: oneThirdWidth + 2,
                absY: 2,
                width: 6,
                height: 1
            ),
            debugID: "SDPALTP"
        )

        artistItemPages = []

        loadArtists()

        loadAlbum()

        loadArtwork()

        loadLyrics()

        updateColors()

    }

    private func loadAlbum() {
        if let album = songDescription.album {
            self.albumItemPage = AlbumItemPage(
                in: borderPlane,
                state: .init(
                    absX: Int32(state.width) / 3 + 4,
                    absY: 4,
                    width: state.width / 3 - 6,
                    height: 5
                ),
                item: album,
                type: .songDetailPage
            )
            self.albumIndexPlane = Plane(
                in: borderPlane,
                state: .init(
                    absX: Int32(state.width) / 3 + 2,
                    absY: 4,
                    width: 2,
                    height: 5
                ),
                debugID: "SDPALIP"
            )
        }
    }

    private func loadArtists() {
        if let artists = songDescription.artists {
            if artists.count > 0 {
                self.artistsIndicesPlane = Plane(
                    in: plane,
                    state: .init(
                        absX: Int32(state.width) / 3 * 2 + 2,
                        absY: 4,
                        width: 2,
                        height: 5 * UInt32(min(maxItemsDisplayed + 1, artists.count))
                    ),
                    debugID: "SDPARIP"
                )
            }
            for artistIndex in 0..<artists.count {
                if maxItemsDisplayed < artistIndex {
                    break
                }
                Task {
                    let artistItem = await ArtistItemPage(
                        in: borderPlane,
                        state: .init(
                            absX: Int32(state.width) / 3 * 2 + 4,
                            absY: 4 + Int32(artistIndex * 5),
                            width: state.width / 3 - 6,
                            height: 5
                        ),
                        item: artists[artistIndex],
                        type: .songDetailPage
                    )
                    artistItemPages.append(artistItem)
                }
            }
        }
    }

    private func loadArtwork() {
        Task {
            if let url = songDescription.song.artwork?.url(
                width: Int(Config.shared.ui.artwork.width),
                height: Int(Config.shared.ui.artwork.height)
            ) {
                downloadImageAndConvertToRGBA(
                    url: url,
                    width: Int(Config.shared.ui.artwork.width),
                    heigth: Int(Config.shared.ui.artwork.height)
                ) { pixelArray in
                    if let pixelArray = pixelArray {
                        await logger?.debug(
                            "SongDetailPage: Successfully obtained artwork RGBA byte array with count: \(pixelArray.count)"
                        )
                        Task { @MainActor in
                            self.handleArtwork(pixelArray: pixelArray)
                        }
                    } else {
                        await logger?.error("SongDetailPage: Failed to get artwork RGBA byte array.")
                    }
                }
            }
        }
    }

    func handleArtwork(pixelArray: [UInt8]) {
        let artworkPlaneWidth = state.width / 3 - 5
        let artworkPlaneHeight = artworkPlaneWidth / 2 - 1
        if artworkPlaneHeight > self.state.height - 12 {  // TODO: fix
            self.artworkVisual?.destroy()
            self.artworkPlane.updateByPageState(
                .init(
                    absX: 0,
                    absY: 0,
                    width: 1,
                    height: 1
                )
            )
            return
        }
        self.artworkPlane.updateByPageState(
            .init(
                absX: 4,
                absY: 6,
                width: artworkPlaneWidth,
                height: artworkPlaneHeight
            )
        )
        self.artworkVisual?.destroy()
        self.artworkVisual = Visual(
            in: UI.notcurses!,
            width: Int32(Config.shared.ui.artwork.width),
            height: Int32(Config.shared.ui.artwork.height),
            from: pixelArray,
            for: self.artworkPlane,
            blit: Config.shared.ui.artwork.blit
        )
        self.artworkVisual?.render()
    }

    private func loadLyrics() {
        Task {
            if let lyricsText = await LyricsManager.shared.fetchLyrics(for: songDescription.song) {
                await logger?.debug("SongDetailPage: Successfully fetched lyrics for '\(songDescription.song.title)'")
                await self.handleLyrics(lyricsText: lyricsText)
            } else {
                await logger?.debug("SongDetailPage: No lyrics available for '\(songDescription.song.title)'")
            }
        }
    }

    @MainActor
    private func handleLyrics(lyricsText: String) {
        self.lyrics = lyricsText
        
        // Create lyrics title plane
        let lyricsStartY = Int32(state.height) - 8
        self.lyricsTitlePlane = Plane(
            in: plane,
            state: .init(
                absX: 4,
                absY: lyricsStartY,
                width: 7,
                height: 1
            ),
            debugID: "SDPLT"
        )
        
        // Create lyrics content plane (limited height for now)
        // Create lyrics content plane (limited height for now)
        let lyricsHeight = min(maxLyricsDisplayHeight, UInt32(lyricsText.split(separator: "\n").count))
        self.lyricsPlane = Plane(
            in: plane,
            state: .init(
                absX: 4,
                absY: lyricsStartY + 1,
                width: state.width - 8,
                height: lyricsHeight
            ),
            debugID: "SDPLP"
        )
    }

    private func updateLyricsDisplay() {
        guard let lyrics = lyrics,
              let lyricsTitlePlane = lyricsTitlePlane,
              let lyricsPlane = lyricsPlane else {
            return
        }
        
        // Display lyrics title
        lyricsTitlePlane.putString("Lyrics:", at: (0, 0))
        
        // Display lyrics content (first few lines)
        let lyricsLines = lyrics.split(separator: "\n")
        let maxLines = min(Int(lyricsPlane.height), lyricsLines.count)
        
        for (index, line) in lyricsLines.prefix(maxLines).enumerated() {
            let truncatedLine = String(line.prefix(Int(lyricsPlane.width - 2)))
            lyricsPlane.putString(truncatedLine, at: (0, Int32(index)))
        }
    }

    public func destroy() async {
        self.plane.erase()
        self.plane.destroy()

        self.borderPlane.erase()
        self.borderPlane.destroy()

        self.artworkVisual?.destroy()
        self.artworkPlane.erase()
        self.artworkPlane.destroy()

        self.songTitlePlane.erase()
        self.songTitlePlane.destroy()

        self.albumTitlePlane?.erase()
        self.albumTitlePlane?.destroy()

        self.albumIndexPlane?.erase()
        self.albumIndexPlane?.blank()
        self.albumIndexPlane?.destroy()

        self.artistsTitlePlane?.erase()
        self.artistsTitlePlane?.destroy()

        self.artistsIndicesPlane?.erase()
        self.artistsIndicesPlane?.destroy()

        self.lyricsTitlePlane?.erase()
        self.lyricsTitlePlane?.destroy()

        self.lyricsPlane?.erase()
        self.lyricsPlane?.destroy()

        await self.albumItemPage?.destroy()
        for artistPage in self.artistItemPages {
            await artistPage?.destroy()
        }
    }

    public func render() async {

    }

    public func updateColors() {
        let colorConfig = Theme.shared.songDetail

        self.plane.setColorPair(colorConfig.page)
        self.plane.blank()

        self.borderPlane.setColorPair(colorConfig.border)
        self.borderPlane.windowBorder(width: state.width, height: state.height)

        self.songTitlePlane.setColorPair(colorConfig.songTitle)
        self.songTitlePlane.putString(self.songDescription.song.title, at: (0, 0))

        self.albumTitlePlane?.setColorPair(colorConfig.albumText)
        if songDescription.album != nil {
            self.albumTitlePlane?.putString("Album:", at: (0, 0))
            self.albumIndexPlane?.setColorPair(colorConfig.albumIndex)
            self.albumIndexPlane?.putString("a0", at: (0, 2))
        }

        self.artistsTitlePlane?.setColorPair(colorConfig.artistsText)
        self.artistsIndicesPlane?.setColorPair(colorConfig.artistIndices)
        if songDescription.artists != nil && !songDescription.artists!.isEmpty {
            self.artistsTitlePlane?.putString("Artists:", at: (0, 0))
            for artistIndex in 0..<songDescription.artists!.count {
                if maxItemsDisplayed < artistIndex {
                    break
                }
                self.artistsIndicesPlane?.putString("w\(artistIndex)", at: (0, 2 + Int32(artistIndex * 5)))
            }
        }

        self.albumItemPage?.updateColors()
        for page in artistItemPages {
            page?.updateColors()
        }

        // Update lyrics display colors
        if lyrics != nil {
            self.lyricsTitlePlane?.setColorPair(colorConfig.artistsText) // Reuse existing color config
            self.lyricsPlane?.setColorPair(colorConfig.page)
            updateLyricsDisplay()
        }
    }

    public func onResize(newPageState: PageState) async {
        self.state = newPageState

        plane.updateByPageState(state)

        borderPlane.updateByPageState(.init(absX: 0, absY: 0, width: state.width, height: state.height))
        borderPlane.erase()
        borderPlane.windowBorder(width: state.width, height: state.height)

    }

    public func getPageState() async -> PageState { state }

    public func getMinDimensions() async -> (width: UInt32, height: UInt32) { (23, 23) }

    public func getMaxDimensions() async -> (width: UInt32, height: UInt32)? { nil }

}
