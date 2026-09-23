import AppKit
import Combine
import SwiftUI

@main
@MainActor
struct CalendarBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The menu bar item is owned by AppKit (see StatusItemController). A
        // scene is still required, so provide an empty Settings scene.
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let manager = CalendarManager()
        statusItemController = StatusItemController(
            manager: manager,
            launchAtLogin: LaunchAtLoginManager(),
            displayModeStore: MenuBarDisplayModeStore()
        )
        manager.requestAccessAndStart()
    }
}

@MainActor
final class MenuBarDisplayModeStore: ObservableObject {
    private static let key = "menuBarDisplayMode"

    @Published var mode: MenuBarDisplayMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.key) }
    }

    init() {
        mode = UserDefaults.standard.string(forKey: Self.key)
            .flatMap(MenuBarDisplayMode.init(rawValue:)) ?? .compact
    }
}

/// Owns the NSStatusItem and its popover.
///
/// SwiftUI's `MenuBarExtra` ignores frame modifiers on its label and always
/// sizes the status item to the rendered text, so the item (and every item to
/// its left) shifts whenever the title changes. Here the item gets a fixed
/// `length` per display mode and the label is drawn into a fixed-size image,
/// so its footprint never changes.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let manager: CalendarManager
    private let launchAtLogin: LaunchAtLoginManager
    private let displayModeStore: MenuBarDisplayModeStore
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var cancellables: Set<AnyCancellable> = []
    private var lastRenderedLabel: (mode: MenuBarDisplayMode, title: String?)?
    private var widthPin = StatusItemWidthPin()

    init(
        manager: CalendarManager,
        launchAtLogin: LaunchAtLoginManager,
        displayModeStore: MenuBarDisplayModeStore
    ) {
        self.manager = manager
        self.launchAtLogin = launchAtLogin
        self.displayModeStore = displayModeStore
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.imagePosition = .imageOnly
            button.setAccessibilityLabel("CalendarBar")
        }

        let hostingController = NSHostingController(
            rootView: MenuBarContentView(
                manager: manager,
                launchAtLogin: launchAtLogin,
                displayModeStore: displayModeStore
            )
        )
        hostingController.sizingOptions = .preferredContentSize
        popover.contentViewController = hostingController
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self

        // objectWillChange fires before the new value is stored, so render on
        // the next run loop turn once the change has landed.
        manager.objectWillChange
            .merge(with: displayModeStore.objectWillChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateLabel() }
            .store(in: &cancellables)

        updateLabel()
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        manager.refresh()
        launchAtLogin.refreshStatus()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        button.highlight(true)
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem.button?.highlight(false)
    }

    private func updateLabel() {
        let mode = displayModeStore.mode
        let title = manager.menuBarTitle(for: mode)
        if let last = lastRenderedLabel, last.mode == mode, last.title == title {
            return
        }
        lastRenderedLabel = (mode, title)

        // Pin the width per event: it is sized once when the next event (or
        // the non-countdown title) changes, then held while the countdown
        // ticks down, so the item doesn't shift every minute.
        let pinKey = manager.upcomingEvents.first.map { "\(mode.rawValue)|next|\($0.id)" }
            ?? "\(mode.rawValue)|\(title ?? "")"
        let textWidth = widthPin.width(
            for: pinKey,
            natural: title.map { StatusItemLabelRenderer.naturalTextWidth(of: $0, mode: mode) } ?? 0
        )
        let image = StatusItemLabelRenderer.image(title: title, textWidth: textWidth)
        statusItem.length = image.size.width + StatusItemLabelRenderer.horizontalPadding * 2
        statusItem.button?.image = image
        statusItem.button?.setAccessibilityValue(title)
        statusItem.button?.toolTip = title
    }
}

/// Holds the status item's title width steady for as long as the key (the
/// event being counted down to) stays the same. The countdown only shrinks, so
/// the width is set when the key changes and only ever grows after that (for
/// example if the event is renamed), never shrinking and shifting each minute.
struct StatusItemWidthPin {
    private var key: String?
    private var width: CGFloat = 0

    mutating func width(for key: String, natural: CGFloat) -> CGFloat {
        if key != self.key {
            self.key = key
            width = natural
        } else {
            width = max(width, natural)
        }
        return width
    }
}

enum StatusItemLabelRenderer {
    static let horizontalPadding: CGFloat = 4
    private static let iconSize: CGFloat = 16
    private static let iconTextSpacing: CGFloat = 4
    private static let imageHeight: CGFloat = 18

    private static var font: NSFont {
        let base = NSFont.menuBarFont(ofSize: 0)
        return NSFont.monospacedDigitSystemFont(ofSize: base.pointSize, weight: .regular)
    }

    /// Upper bound on the title width in Full mode; longer titles truncate.
    static let maximumFullTextWidth: CGFloat = 190

    /// Width the title needs, with every digit measured as "0" so a pinned
    /// width never depends on which digits the countdown currently shows.
    static func naturalTextWidth(of title: String, mode: MenuBarDisplayMode) -> CGFloat {
        let normalized = String(title.map { $0.isNumber ? "0" : $0 })
        let width = ceil((normalized as NSString).size(withAttributes: [.font: font]).width)
        return mode == .full ? min(width, maximumFullTextWidth) : width
    }

    /// Renders the icon and title into a single template image of fixed size.
    /// Template images are tinted by the menu bar, so light, dark, and
    /// highlighted appearances are handled by the system.
    static func image(title: String?, textWidth: CGFloat) -> NSImage {
        let width = iconSize + (title == nil ? 0 : iconTextSpacing + textWidth)
        let size = NSSize(width: width, height: imageHeight)

        let image = NSImage(size: size, flipped: false) { _ in
            drawIcon(in: NSRect(x: 0, y: (imageHeight - iconSize) / 2, width: iconSize, height: iconSize))
            if let title {
                drawTitle(
                    title,
                    in: NSRect(x: iconSize + iconTextSpacing, y: 0, width: textWidth, height: imageHeight)
                )
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawIcon(in rect: NSRect) {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        guard let symbol = NSImage(systemSymbolName: "calendar", accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else { return }

        let symbolSize = symbol.size
        let origin = NSPoint(
            x: rect.midX - symbolSize.width / 2,
            y: rect.midY - symbolSize.height / 2
        )
        symbol.draw(in: NSRect(origin: origin, size: symbolSize))
    }

    private static func drawTitle(_ title: String, in rect: NSRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraph,
        ]

        let lineHeight = ceil(font.ascender - font.descender)
        let textRect = NSRect(
            x: rect.minX,
            y: rect.midY - lineHeight / 2,
            width: rect.width,
            height: lineHeight
        )

        // Truncate only the event title, never the countdown suffix, so a long
        // title can't push the countdown out of the reserved width.
        let parts = MenuBarTitleFormatter.splitCountdown(title)
        let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
        guard let suffix = parts.suffix else {
            (title as NSString).draw(with: textRect, options: options, attributes: attributes)
            return
        }

        let suffixWidth = ceil((suffix as NSString).size(withAttributes: attributes).width)
        let leadingWidth = min(
            ceil((parts.leading as NSString).size(withAttributes: attributes).width),
            max(0, textRect.width - suffixWidth)
        )
        var leadingRect = textRect
        leadingRect.size.width = leadingWidth
        var suffixRect = textRect
        suffixRect.origin.x = textRect.minX + leadingWidth
        suffixRect.size.width = suffixWidth

        (parts.leading as NSString).draw(with: leadingRect, options: options, attributes: attributes)
        (suffix as NSString).draw(with: suffixRect, options: [.usesLineFragmentOrigin], attributes: attributes)
    }
}
