import AppKit

/// The menu bar glyph: a trackpad outline with a bar on each edge. Drawn as a template image so
/// macOS tints it for light, dark and highlighted menu bars.
public enum MenuBarIcon {
    public static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let outline = NSBezierPath(roundedRect: NSRect(x: 1.75, y: 3.75, width: 14.5, height: 10.5), xRadius: 2.6, yRadius: 2.6)
            outline.lineWidth = 1.5
            NSColor.black.setStroke()
            outline.stroke()

            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: 4.25, y: 6.25, width: 2, height: 5.5), xRadius: 1, yRadius: 1).fill()
            NSBezierPath(roundedRect: NSRect(x: 11.75, y: 6.25, width: 2, height: 5.5), xRadius: 1, yRadius: 1).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "OpenEdgeBar"
        return image
    }()
}
