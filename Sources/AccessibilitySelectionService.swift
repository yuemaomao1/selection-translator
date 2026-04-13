import AppKit
import ApplicationServices

final class AccessibilitySelectionService {
    func decisionForTrigger() -> TranslateTriggerDecision {
        guard AXIsProcessTrusted() else {
            return .passThrough
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )

        guard focusedResult == .success, let focusedRef, CFGetTypeID(focusedRef) == AXUIElementGetTypeID() else {
            return .passThrough
        }

        let element = unsafeBitCast(focusedRef, to: AXUIElement.self)
        let fallback = mouseFallbackRect()

        let range = readSelectedRange(from: element)
        let text = readSelectedText(from: element)?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let range, range.length > 0, let text, !text.isEmpty {
            let bounds = readBounds(for: range, from: element) ?? fallback
            return .translate(
                SelectedTextContext(
                    text: text,
                    selectedRange: range,
                    anchorRect: bounds
                )
            )
        }

        if let range, range.length > 0 {
            return .showError(SelectionError(kind: .unsupportedApp, fallbackRect: fallback))
        }

        if let text, !text.isEmpty {
            return .showError(
                SelectionError(
                    kind: .unsupportedApp,
                    fallbackRect: fallback
                )
            )
        }

        return .passThrough
    }

    func readCurrentSelection() -> Result<SelectedTextContext, SelectionError> {
        guard AXIsProcessTrusted() else {
            return .failure(SelectionError(kind: .permissionDenied, fallbackRect: mouseFallbackRect()))
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )

        guard focusedResult == .success, let focusedRef, CFGetTypeID(focusedRef) == AXUIElementGetTypeID() else {
            return .failure(SelectionError(kind: .missingFocusedElement, fallbackRect: mouseFallbackRect()))
        }

        let element = unsafeBitCast(focusedRef, to: AXUIElement.self)

        guard let range = readSelectedRange(from: element) else {
            return .failure(SelectionError(kind: .unsupportedApp, fallbackRect: mouseFallbackRect()))
        }

        if range.length == 0 {
            return .failure(SelectionError(kind: .emptySelection, fallbackRect: mouseFallbackRect()))
        }

        guard let text = readSelectedText(from: element)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return .failure(SelectionError(kind: .unsupportedApp, fallbackRect: mouseFallbackRect()))
        }

        let bounds = readBounds(for: range, from: element) ?? mouseFallbackRect()
        return .success(
            SelectedTextContext(
                text: text,
                selectedRange: range,
                anchorRect: bounds
            )
        )
    }

    func mouseFallbackRect() -> CGRect {
        let mousePoint = NSEvent.mouseLocation
        return CGRect(x: mousePoint.x, y: mousePoint.y, width: 1, height: 1)
    }

    private func readSelectedText(from element: AXUIElement) -> String? {
        var selectedTextRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedTextRef
        )

        guard result == .success, let selectedTextRef else {
            return nil
        }

        return selectedTextRef as? String
    }

    private func readSelectedRange(from element: AXUIElement) -> CFRange? {
        var selectedRangeRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRangeRef
        )

        guard result == .success,
              let value = selectedRangeRef,
              CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }

        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cfRange else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range) else {
            return nil
        }
        return range
    }

    private func readBounds(for range: CFRange, from element: AXUIElement) -> CGRect? {
        var mutableRange = range
        guard let rangeValue = AXValueCreate(.cfRange, &mutableRange) else {
            return nil
        }
        return fetchBounds(from: element, rangeValue: rangeValue)
    }

    private func fetchBounds(from element: AXUIElement, rangeValue: AXValue) -> CGRect? {
        var boundsRef: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &boundsRef
        )

        guard result == .success,
              let boundsRef,
              CFGetTypeID(boundsRef) == AXValueGetTypeID()
        else {
            return nil
        }

        let axValue = unsafeBitCast(boundsRef, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgRect else {
            return nil
        }

        var rect = CGRect.zero
        guard AXValueGetValue(axValue, .cgRect, &rect) else {
            return nil
        }
        return rect
    }
}
