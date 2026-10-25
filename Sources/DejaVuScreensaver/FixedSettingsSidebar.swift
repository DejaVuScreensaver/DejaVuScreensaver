import AppKit
import SwiftUI

// SwiftUI's column limits do not constrain the native pane in our AppKit-hosted settings window.
struct FixedSettingsSidebar: NSViewRepresentable {
    func makeNSView(context: Context) -> SidebarWidthView { SidebarWidthView() }

    func updateNSView(_ nsView: SidebarWidthView, context: Context) {
        nsView.pinSidebarWidth()
    }

    final class SidebarWidthView: NSView {
        private weak var widthConstraint: NSLayoutConstraint?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            // SwiftUI finishes constructing the native split view after attaching its content.
            DispatchQueue.main.async { [weak self] in self?.pinSidebarWidth() }
        }

        func pinSidebarWidth() {
            var ancestor = superview
            while let view = ancestor {
                if let split = view as? NSSplitView, split.isVertical,
                   let sidebar = split.arrangedSubviews.first {
                    guard widthConstraint?.firstItem !== sidebar else { return }
                    widthConstraint?.isActive = false
                    let constraint = sidebar.widthAnchor.constraint(equalToConstant: 250)
                    constraint.identifier = "DejaVuSettingsSidebarWidth"
                    constraint.isActive = true
                    widthConstraint = constraint
                    return
                }
                ancestor = view.superview
            }
        }
    }
}
