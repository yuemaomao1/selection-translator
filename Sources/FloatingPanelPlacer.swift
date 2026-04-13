import AppKit

enum FloatingPanelPlacer {
    static func place(panelSize: NSSize, around anchorRect: CGRect) -> NSRect {
        let screen = screen(for: anchorRect) ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let gap: CGFloat = 12

        let candidates = [
            CGPoint(x: anchorRect.maxX + gap, y: anchorRect.midY - panelSize.height / 2),
            CGPoint(x: anchorRect.midX - panelSize.width / 2, y: anchorRect.minY - gap - panelSize.height),
            CGPoint(x: anchorRect.minX - gap - panelSize.width, y: anchorRect.midY - panelSize.height / 2),
            CGPoint(x: anchorRect.midX - panelSize.width / 2, y: anchorRect.maxY + gap)
        ]

        for origin in candidates {
            let clamped = clamp(origin: origin, size: panelSize, to: visibleFrame)
            let frame = CGRect(origin: clamped, size: panelSize)
            if !frame.intersects(anchorRect) {
                return frame
            }
        }

        let fallbackOrigin = clamp(
            origin: CGPoint(x: anchorRect.maxX + gap, y: anchorRect.minY - panelSize.height - gap),
            size: panelSize,
            to: visibleFrame
        )
        return CGRect(origin: fallbackOrigin, size: panelSize)
    }

    private static func clamp(origin: CGPoint, size: NSSize, to visibleFrame: CGRect) -> CGPoint {
        let minX = visibleFrame.minX
        let maxX = visibleFrame.maxX - size.width
        let minY = visibleFrame.minY
        let maxY = visibleFrame.maxY - size.height

        return CGPoint(
            x: min(max(origin.x, minX), maxX),
            y: min(max(origin.y, minY), maxY)
        )
    }

    private static func screen(for rect: CGRect) -> NSScreen? {
        NSScreen.screens.first { $0.frame.intersects(rect) || $0.visibleFrame.contains(rect.origin) }
    }
}
