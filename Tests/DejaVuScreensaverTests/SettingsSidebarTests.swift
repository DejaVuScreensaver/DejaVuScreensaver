import AppKit
import SwiftUI
import XCTest
@testable import DejaVuScreensaver

final class SettingsSidebarTests: XCTestCase {
    func testSidebarCannotGrowOrShrinkAndStaysFixedWhenWindowResizes() async throws {
        let window = await MainActor.run {
            let host = NSHostingController(rootView: SettingsView(
                model: AppModel(), softwareUpdate: SoftwareUpdateController(), onShowHistory: {}
            ))
            let window = NSWindow(contentViewController: host)
            window.setContentSize(NSSize(width: 890, height: 700))
            window.contentView?.layoutSubtreeIfNeeded()
            return window
        }
        try await Task.sleep(nanoseconds: 150_000_000)
        try await MainActor.run {
            defer { window.close() }
            let split = try XCTUnwrap(findSplitView(in: window.contentView!))
            XCTAssertEqual(split.arrangedSubviews[0].frame.width, 250, accuracy: 1)
            for position in [450.0, 150.0] {
                split.setPosition(position, ofDividerAt: 0)
                window.contentView?.layoutSubtreeIfNeeded()
                XCTAssertEqual(split.arrangedSubviews[0].frame.width, 250, accuracy: 1)
            }
            for width in [1200.0, 870.0] {
                window.setContentSize(NSSize(width: width, height: 700))
                window.contentView?.layoutSubtreeIfNeeded()
                XCTAssertEqual(split.arrangedSubviews[0].frame.width, 250, accuracy: 1)
                XCTAssertGreaterThan(split.arrangedSubviews[1].frame.width, 600)
            }
        }
    }

    @MainActor
    private func findSplitView(in view: NSView) -> NSSplitView? {
        if let split = view as? NSSplitView, split.isVertical, split.arrangedSubviews.count == 2 {
            return split
        }
        return view.subviews.lazy.compactMap { self.findSplitView(in: $0) }.first
    }
}
