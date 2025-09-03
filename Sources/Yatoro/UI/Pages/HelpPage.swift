import Foundation
import Logging
import SwiftNotCurses

@MainActor
public class HelpPage: DestroyablePage {

    private let plane: Plane
    private let pagePlane: Plane
    private let pageNamePlane: Plane
    private let borderPlane: Plane
    private let contentPlane: Plane

    private var state: PageState

    public func onResize(newPageState: PageState) async {
        self.state = newPageState
        plane.updateByPageState(state)
        
        pagePlane.updateByPageState(
            .init(
                absX: 1,
                absY: 1,
                width: state.width - 2,
                height: state.height - 2
            )
        )
        pagePlane.blank()
        
        borderPlane.updateByPageState(
            .init(
                absX: 0,
                absY: 0,
                width: state.width,
                height: state.height
            )
        )
        borderPlane.erase()
        borderPlane.windowBorder(width: state.width, height: state.height)
        
        contentPlane.updateByPageState(
            .init(
                absX: 2,
                absY: 2,
                width: state.width - 4,
                height: state.height - 4
            )
        )
        contentPlane.erase()
        
        renderHelpContent()
    }

    public func getMinDimensions() async -> (width: UInt32, height: UInt32) { (40, 15) }

    public func getMaxDimensions() async -> (width: UInt32, height: UInt32)? { nil }

    public func getPageState() async -> PageState { self.state }

    public init?(
        stdPlane: Plane,
        state: PageState
    ) {
        self.state = state
        guard
            let plane = Plane(
                in: stdPlane,
                state: state,
                debugID: "HELP_PAGE"
            )
        else {
            return nil
        }
        self.plane = plane

        guard
            let borderPlane = Plane(
                in: plane,
                state: .init(
                    absX: 0,
                    absY: 0,
                    width: state.width,
                    height: state.height
                ),
                debugID: "HELP_BORDER"
            )
        else {
            return nil
        }
        self.borderPlane = borderPlane

        guard
            let pageNamePlane = Plane(
                in: plane,
                state: .init(
                    absX: 2,
                    absY: 0,
                    width: 4,
                    height: 1
                ),
                debugID: "HELP_NAME"
            )
        else {
            return nil
        }
        self.pageNamePlane = pageNamePlane

        guard
            let pagePlane = Plane(
                in: plane,
                state: .init(
                    absX: 1,
                    absY: 1,
                    width: state.width - 2,
                    height: state.height - 2
                ),
                debugID: "HELP_PAGE"
            )
        else {
            return nil
        }
        self.pagePlane = pagePlane

        guard
            let contentPlane = Plane(
                in: plane,
                state: .init(
                    absX: 2,
                    absY: 2,
                    width: state.width - 4,
                    height: state.height - 4
                ),
                debugID: "HELP_CONTENT"
            )
        else {
            return nil
        }
        self.contentPlane = contentPlane

        updateColors()
    }

    public func updateColors() {
        let colorConfig = Theme.shared.nowPlaying // Reuse now playing colors for consistency
        borderPlane.setColorPair(colorConfig.border)
        pageNamePlane.setColorPair(colorConfig.pageName)
        pagePlane.setColorPair(colorConfig.page)
        contentPlane.setColorPair(colorConfig.page)

        borderPlane.windowBorder(width: state.width, height: state.height)
        pageNamePlane.putString("Help", at: (0, 0))
        pagePlane.blank()
        
        Task {
            await onResize(newPageState: self.state)
        }
    }

    private func renderHelpContent() {
        contentPlane.erase()
        
        var row: Int32 = 0
        
                // Title
        contentPlane.putString("Yatoro Help - Available Commands", at: (0, row))
        row += 2
        
        // Header
        contentPlane.putString("COMMANDS:", at: (0, row))
        row += 1
        contentPlane.putString("=========", at: (0, row))
        row += 1
        
        // Generate commands list
        let commands = Command.defaultCommands.sorted(by: { $0.name < $1.name })
        
        let maxRows = min(commands.count, Int(contentPlane.height) - 8) // Leave space for header and footer
        
        for i in 0..<maxRows {
            let command = commands[i]
            let shortName = command.shortName ?? ""
            let nameWithShort = shortName.isEmpty ? command.name : "\(command.name) (\(shortName))"
            let commandText = ":\(nameWithShort)"
            contentPlane.putString(commandText, at: (0, row))
            row += 1
        }
        
        // Footer
        row += 1
        contentPlane.putString("Type :help or :h in command mode to open this help page", at: (0, row))
        row += 1
        contentPlane.putString("Press ESC to close this help page", at: (0, row))
    }

    public func render() async {
        // Help page is static, no need to update
    }

    public func destroy() async {
        self.plane.erase()
        self.plane.destroy()

        self.borderPlane.erase()
        self.borderPlane.destroy()

        self.pagePlane.erase()
        self.pagePlane.destroy()

        self.pageNamePlane.erase()
        self.pageNamePlane.destroy()

        self.contentPlane.erase()
        self.contentPlane.destroy()
    }
}
