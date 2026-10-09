import AppKit
import SwiftUI

/// A borderless panel that floats above other apps, including full-screen slideshows.
@MainActor
final class SubtitlePanel {
  /// Tall enough for two history lines above the current subtitle at large font sizes.
  private static let height: CGFloat = 520
  /// The bottom center of the panel, where the subtitles sit, in screen coordinates.
  private static let anchorKey = "subtitleAnchor"

  private let panel: NSPanel
  private var moveObserver: NSObjectProtocol?

  init(content: some View) {
    panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.level = .statusBar
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    panel.isMovableByWindowBackground = true
    panel.contentView = DraggableHostingView(rootView: content)
    place(at: Self.savedAnchor ?? Self.defaultAnchor)
    panel.orderFrontRegardless()

    moveObserver = NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main) { [weak self] _ in
      MainActor.assumeIsolated { self?.saveAnchor() }
    }
  }

  func resetPosition() {
    place(at: Self.defaultAnchor)
    saveAnchor()
  }

  /// Sizes the panel for the screen under `anchor` and keeps it fully inside that screen.
  private func place(at anchor: NSPoint) {
    guard let screen = NSScreen.screens.first(where: { $0.frame.contains(anchor) }) ?? NSScreen.main else { return }
    let visible = screen.visibleFrame
    let size = NSSize(width: visible.width * 0.8, height: min(Self.height, visible.height))
    let x = min(max(anchor.x - size.width / 2, visible.minX), visible.maxX - size.width)
    let y = min(max(anchor.y, visible.minY), visible.maxY - size.height)
    panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)
  }

  private func saveAnchor() {
    UserDefaults.standard.set([panel.frame.midX, panel.frame.minY], forKey: Self.anchorKey)
  }

  private static var savedAnchor: NSPoint? {
    guard let point = UserDefaults.standard.array(forKey: anchorKey) as? [Double], point.count == 2 else { return nil }
    return NSPoint(x: point[0], y: point[1])
  }

  private static var defaultAnchor: NSPoint {
    let visible = NSScreen.main?.visibleFrame ?? .zero
    return NSPoint(x: visible.midX, y: visible.minY + 40)
  }
}

/// Lets the user drag the panel by the subtitle itself.
private final class DraggableHostingView<Content: View>: NSHostingView<Content> {
  override var mouseDownCanMoveWindow: Bool { true }
}
