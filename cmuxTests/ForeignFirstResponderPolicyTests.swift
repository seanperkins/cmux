import AppKit
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

/// Coverage for ``shouldRespectForeignFirstResponder(_:in:isRightSidebarOwner:)`` — the policy that
/// decides whether an active terminal yields to the window's current first responder or reclaims
/// focus. Regression coverage for issue #5269 (a stranded responder must not block focus).
@MainActor
@Suite struct ForeignFirstResponderPolicyTests {
    private func makeWindow() -> NSWindow {
        NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
    }

    private let neverSidebarOwner: (NSResponder) -> Bool = { _ in false }
    private let alwaysSidebarOwner: (NSResponder) -> Bool = { _ in true }

    @Test func respectsInWindowTextEditor() {
        let window = makeWindow()
        let textView = NSTextView(frame: .zero)
        window.contentView?.addSubview(textView)
        #expect(shouldRespectForeignFirstResponder(textView, in: window, isRightSidebarOwner: neverSidebarOwner))
    }

    /// The #5269 regression: a text responder stranded in another window must NOT be respected, so
    /// the terminal can reclaim focus. Without the window-membership check this returns `true`.
    @Test func reclaimsFromStrandedTextEditorInAnotherWindow() {
        let windowA = makeWindow()
        let windowB = makeWindow()
        let textView = NSTextView(frame: .zero)
        windowB.contentView?.addSubview(textView) // belongs to windowB, not windowA
        #expect(!shouldRespectForeignFirstResponder(textView, in: windowA, isRightSidebarOwner: neverSidebarOwner))
    }

    @Test func respectsInWindowRightSidebarOwner() {
        let window = makeWindow()
        let view = NSView(frame: .zero)
        window.contentView?.addSubview(view)
        #expect(shouldRespectForeignFirstResponder(view, in: window, isRightSidebarOwner: alwaysSidebarOwner))
    }

    /// The #5269 regression for the sidebar/dock flavor: a sidebar host stranded in another window
    /// must NOT be respected. Without the window-membership check this returns `true`.
    @Test func reclaimsFromStrandedRightSidebarOwner() {
        let windowA = makeWindow()
        let windowB = makeWindow()
        let view = NSView(frame: .zero)
        windowB.contentView?.addSubview(view)
        #expect(!shouldRespectForeignFirstResponder(view, in: windowA, isRightSidebarOwner: alwaysSidebarOwner))
    }

    @Test func reclaimsFromDetachedResponder() {
        let window = makeWindow()
        let textView = NSTextView(frame: .zero) // never added to a window -> .window is nil
        #expect(!shouldRespectForeignFirstResponder(textView, in: window, isRightSidebarOwner: alwaysSidebarOwner))
    }

    @Test func doesNotRespectPlainInWindowView() {
        let window = makeWindow()
        let view = NSView(frame: .zero)
        window.contentView?.addSubview(view)
        // Neither a text editor nor a sidebar owner: the terminal reclaims focus (existing behavior).
        #expect(!shouldRespectForeignFirstResponder(view, in: window, isRightSidebarOwner: neverSidebarOwner))
    }

    /// The highlighted file-preview editor (CodeEdit's `TextView`) is an `NSView`, not an `NSText`
    /// subclass. The policy must still yield to it, or the pre-dispatch key repair steals every
    /// keystroke back to the terminal while the user edits: clicking places the cursor (mouse events
    /// bypass the repair) but arrow keys and typing never reach the editor.
    @Test func respectsInWindowFilePreviewTextInsertionTarget() {
        let window = makeWindow()
        let editor = StubFilePreviewEditorView(frame: .zero)
        window.contentView?.addSubview(editor)
        #expect(shouldRespectForeignFirstResponder(editor, in: window, isRightSidebarOwner: neverSidebarOwner))
    }

    /// A file-preview editor stranded in another window must not block the terminal, matching the
    /// #5269 stranded-responder rule for the other focus-owner flavors.
    @Test func reclaimsFromStrandedFilePreviewTextInsertionTarget() {
        let windowA = makeWindow()
        let windowB = makeWindow()
        let editor = StubFilePreviewEditorView(frame: .zero)
        windowB.contentView?.addSubview(editor)
        #expect(!shouldRespectForeignFirstResponder(editor, in: windowA, isRightSidebarOwner: neverSidebarOwner))
    }
}

/// Mirrors the highlighted file-preview editor's shape: a text-insertion target that is a plain
/// `NSView`, not an `NSText` subclass.
@MainActor
private final class StubFilePreviewEditorView: NSView, FilePreviewTextInsertionTarget {
    var filePreviewCurrentText: String { "" }
    func focusFilePreviewTextTarget() {}
    func insertFilePreviewText(_ text: String) {}
}
