import Foundation
import Logging
import SwiftNotCurses

@MainActor
public class HelpPage: DestroyablePage {

    private let plane: Plane
    private let pagePlane: Plane
    private let borderPlane: Plane
    private let pageNamePlane: Plane
    private let contentPlane: Plane

    private var state: PageState
    // MARK: - Properties
    
    // Active reference
    /// The currently active HelpPage instance.
    public static weak var active: HelpPage?
    // MARK: - Constants
    
    private static let minPageWidth: Int32 = 4
    private static let minPageHeight: Int32 = 4
    private static let defaultMarginX: Int32 = 5
    private static let defaultMarginTop: Int32 = 2
    private static let defaultMarginBottom: Int32 = 4

    // MARK: - Layout Logic
    
    /// Calculates the optimal layout for the HelpPage based on the parent's dimensions.
    /// - Parameter parentState: The state of the parent container (usually the window or main content area).
    /// - Returns: A new `PageState` with calculated position and size, ensuring the page fits within bounds.
    public static func layout(forParent parentState: PageState) -> PageState {
        let parentWidth = Int32(parentState.width)
        let parentHeight = Int32(parentState.height)
        
        var marginX: Int32 = defaultMarginX
        var marginTop: Int32 = defaultMarginTop
        var marginBottom: Int32 = defaultMarginBottom
        
        // Dynamically reduce margins if the window is too small to fit content
        if parentWidth < (minPageWidth + marginX * 2) {
            marginX = max(0, (parentWidth - minPageWidth) / 2)
        }
        if parentHeight < (minPageHeight + marginTop + marginBottom) {
            let availableMargin = max(0, parentHeight - minPageHeight)
            // Distribute approx 1/3 top, 2/3 bottom
            marginTop = availableMargin / 3
            marginBottom = availableMargin - marginTop
        }
        
        let newWidth = max(minPageWidth, parentWidth - (marginX * 2))
        let newHeight = max(minPageHeight, parentHeight - (marginTop + marginBottom))
        
        return PageState(
            absX: marginX,
            absY: marginTop,
            width: UInt32(newWidth),
            height: UInt32(newHeight)
        )
    }
    
    /// Resizes the HelpPage to fit within the given parent state, using the standard layout logic.
    public func resizeToParent(_ parentState: PageState) async {
        await onResize(newPageState: HelpPage.layout(forParent: parentState))
    }

    public func onResize(newPageState: PageState) async {
        self.state = newPageState
        
        guard state.width >= UInt32(HelpPage.minPageWidth),
              state.height >= UInt32(HelpPage.minPageHeight) else {
            return
        }
        
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

        pageNamePlane.updateByPageState(.init(absX: 2, absY: 0, width: 4, height: 1))

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
    
    public func getMinDimensions() async -> (width: UInt32, height: UInt32) { (50, 20) }

    public func getMaxDimensions() async -> (width: UInt32, height: UInt32)? { nil }

    public func getPageState() async -> PageState { self.state }
    
    public init?(
        stdPlane: Plane,
        state: PageState
    ) {
        if state.width <= HelpPage.minPageWidth || state.height <= HelpPage.minPageHeight {
            return nil
        }
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
            let pagePlane = Plane(
                in: plane,
                state: .init(
                    absX: 1,
                    absY: 1,
                    width: state.width - 2,
                    height: state.height - 2
                ),
                debugID: "HELP_PAGE_BG"
            )
        else {
            return nil
        }
        self.pagePlane = pagePlane


        guard
            let pageNamePlane = Plane(
                in: plane,
                state: .init(
                    absX: 2,
                    absY: 0,
                    width: 4,
                    height: 1
                ),
                debugID: "HELP_PAGE_NAME"
            )
        else {
            return nil
        }
        self.pageNamePlane = pageNamePlane

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
        
        HelpPage.active = self
    }

    public func updateColors() {
        let colorConfig = Theme.shared.nowPlaying 
        
        plane.setColorPair(colorConfig.page)
        pagePlane.setColorPair(colorConfig.page)
        borderPlane.setColorPair(colorConfig.border)
        pageNamePlane.setColorPair(colorConfig.pageName)
        contentPlane.setColorPair(colorConfig.page)
        
        plane.blank()
        borderPlane.windowBorder(width: state.width, height: state.height)
        pageNamePlane.putString("Help", at: (0, 0))
        pagePlane.blank()
        
        contentPlane.blank()
        renderHelpContent()
    }

    private func renderHelpContent() {
        contentPlane.erase()

        
        var row: Int32 = 0
        
        renderGeneralHelp(row: &row)
        
        // Footer
        row += 2
        contentPlane.putString("Press ESC to close this help page", at: (0, row))
    }



    private func renderGeneralHelp(row: inout Int32) {
        let width = Int(contentPlane.width)
        let midPoint = width / 2
        
        // Title
        contentPlane.putString("Yatoro Help - Commands and Key Bindings", at: (0, row))
        row += 2
        
        // Table Headers
        contentPlane.putString("COMMANDS:", at: (0, row))
        contentPlane.putString("KEY BINDINGS:", at: (Int32(midPoint), row))
        row += 1
        
        // Header Separator
        let leftSep = String(repeating: "=", count: 9) // Length of "COMMANDS:"
        let rightSep = String(repeating: "=", count: 13) // Length of "KEY BINDINGS:"
        contentPlane.putString(leftSep, at: (0, row))
        contentPlane.putString(rightSep, at: (Int32(midPoint), row))
        row += 1
        
        let commands = Command.defaultCommands
        let mappings = Config.shared.mappings
        
        for command in commands {
            // Left Column: Command
            let commandPart = ":\(command.name)"
            contentPlane.putString(commandPart, at: (0, row))
            
            // Right Column: Shortcut -> Binding
            var rightTextParts: [String] = []
            
            if let shortName = command.shortName, !shortName.isEmpty {
                rightTextParts.append(":\(shortName)")
            }
            
            let prefix = ":\(command.name)"
            if let mapping = mappings.first(where: { m in
                 let action = m.action
                 guard action.hasPrefix(prefix) else { return false }
                 let suffix = action.dropFirst(prefix.count)
                 return suffix.isEmpty || suffix.hasPrefix("<") || suffix.hasPrefix(" ")
            }) {
                rightTextParts.append(mapping.displayKey)
            }
            
            if !rightTextParts.isEmpty {
                let rightText = rightTextParts.joined(separator: " -> ")
                contentPlane.putString(rightText, at: (Int32(midPoint), row))
            }
            
            row += 1
        }
    }

    public func render() async {
        // Help page is static
    }

    public func destroy() async {
        self.borderPlane.erase()
        self.borderPlane.destroy()
        
        self.pageNamePlane.erase()
        self.pageNamePlane.destroy()
        
        self.pagePlane.erase()
        self.pagePlane.destroy()
        
        self.contentPlane.erase()
        self.contentPlane.destroy()
        
        self.plane.erase()
        self.plane.destroy()
        
        if HelpPage.active === self {
            HelpPage.active = nil
        }
    }
}

// MARK: - Mapping Display Extension
extension Mapping {
    var displayKey: String {
        guard let modifiers = modifiers, !modifiers.isEmpty else {
            return key
        }
        let keyStr = modifiers.map { $0.rawValue.uppercased() }.joined(separator: "+")
        return "\(keyStr)+\(key)"
    }
}