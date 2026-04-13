import AppKit
import ApplicationServices
import Foundation

enum ClipboardFallbackError: LocalizedError {
    case unavailable
    case timedOut
    case emptyClipboard

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "剪贴板兜底未能触发复制"
        case .timedOut:
            return "剪贴板兜底超时，当前应用可能不支持 Cmd+C 复制选区"
        case .emptyClipboard:
            return "剪贴板里没有可翻译文本"
        }
    }
}

final class ClipboardFallbackService {
    private static let keycodeC: CGKeyCode = 8

    func captureSelectedTextViaCopyShortcut(timeout: TimeInterval = 0.35) -> Result<String, ClipboardFallbackError> {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot.capture(from: pasteboard)
        let initialChangeCount = pasteboard.changeCount

        guard simulateCommandC() else {
            return .failure(.unavailable)
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))

            guard pasteboard.changeCount != initialChangeCount else {
                continue
            }

            let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
            snapshot.restore(to: pasteboard)

            guard let text, !text.isEmpty else {
                return .failure(.emptyClipboard)
            }

            return .success(text)
        }

        snapshot.restore(to: pasteboard)
        return .failure(.timedOut)
    }

    private func simulateCommandC() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: Self.keycodeC, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: Self.keycodeC, keyDown: false)
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
        return true
    }
}

private struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            item.types.reduce(into: [NSPasteboard.PasteboardType: Data]()) { partialResult, type in
                if let data = item.data(forType: type) {
                    partialResult[type] = data
                }
            }
        }
        return PasteboardSnapshot(items: items)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()

        guard !items.isEmpty else { return }

        let restoredItems = items.map { itemData -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in itemData {
                item.setData(data, forType: type)
            }
            return item
        }

        pasteboard.writeObjects(restoredItems)
    }
}
