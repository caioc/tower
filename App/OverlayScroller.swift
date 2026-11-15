import AppKit
import SwiftUI

// Puts the enclosing NSScrollView in overlay style, so the panel shows a thin scroller that fades out
// even when System Settings asks for scroll bars that are always visible.
struct OverlayScroller: NSViewRepresentable {
  func makeNSView(context _: Context) -> OverlayScrollerView { OverlayScrollerView() }
  func updateNSView(_ view: OverlayScrollerView, context _: Context) { view.applyOverlayStyle() }
}

final class OverlayScrollerView: NSView {
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    NotificationCenter.default.removeObserver(self)
    guard window != nil else { return }
    // AppKit resets the scroller style when the system preference changes, so apply it again after that.
    NotificationCenter.default.addObserver(
      self, selector: #selector(preferredScrollerStyleDidChange),
      name: NSScroller.preferredScrollerStyleDidChangeNotification, object: nil)
    applyOverlayStyle()
  }

  @objc private func preferredScrollerStyleDidChange() {
    DispatchQueue.main.async { [weak self] in self?.applyOverlayStyle() }
  }

  func applyOverlayStyle() {
    guard let scrollView = enclosingScrollView, scrollView.scrollerStyle != .overlay else { return }
    scrollView.scrollerStyle = .overlay
    scrollView.autohidesScrollers = true
  }
}
