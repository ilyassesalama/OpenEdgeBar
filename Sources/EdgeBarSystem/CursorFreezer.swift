import CoreGraphics

/// Keeps the pointer still while a finger slides an edge.
///
/// Disconnecting the mouse from the cursor stops trackpad movement without an event tap. The
/// pointer has already drifted a little before a touch counts as a slide, so it is put back where
/// it was when the finger landed.
@MainActor
public final class CursorFreezer {
    private var anchor: CGPoint?
    public private(set) var isFrozen = false

    public init() {}

    /// Remember where the pointer is, in case this touch becomes a slide.
    public func rememberPosition() {
        anchor = CGEvent(source: nil)?.location
    }

    public func freeze() {
        guard !isFrozen else { return }
        isFrozen = true
        _ = CGAssociateMouseAndMouseCursorPosition(0)
        if let anchor {
            _ = CGWarpMouseCursorPosition(anchor)
        }
    }

    public func release() {
        anchor = nil
        guard isFrozen else { return }
        isFrozen = false
        // Reconnecting last also cancels the short input freeze that follows a warp.
        _ = CGAssociateMouseAndMouseCursorPosition(1)
    }
}
