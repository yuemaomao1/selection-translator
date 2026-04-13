import AppKit

struct SelectedTextContext {
    let text: String
    let selectedRange: CFRange
    let anchorRect: CGRect
}

struct TriggerShortcut: Equatable {
    let key: String
    let modifiers: NSEvent.ModifierFlags

    static let defaultShortcut = TriggerShortcut(key: "t", modifiers: [])

    var displayName: String {
        let modifierParts = Self.orderedModifierParts(for: modifiers)
        let keyPart = Self.displayName(forKey: key)
        return (modifierParts + [keyPart]).joined(separator: "+")
    }

    static func from(event: NSEvent) -> TriggerShortcut? {
        guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else {
            return nil
        }

        guard let normalizedKey = normalizedKeyToken(from: characters) else {
            return nil
        }

        return TriggerShortcut(
            key: normalizedKey,
            modifiers: normalizedModifiers(event.modifierFlags)
        )
    }

    static func normalizedModifiers(_ flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        flags.intersection([.command, .control, .option, .shift])
    }

    static func normalizedKeyToken(from raw: String) -> String? {
        let lowercased = raw.lowercased()

        if lowercased == " " {
            return "space"
        }

        if lowercased.count == 1, let scalar = lowercased.unicodeScalars.first {
            let allowed = CharacterSet.alphanumerics
            if allowed.contains(scalar) {
                return lowercased
            }
        }

        return nil
    }

    private static func displayName(forKey key: String) -> String {
        if key == "space" {
            return "Space"
        }
        return key.uppercased()
    }

    private static func orderedModifierParts(for flags: NSEvent.ModifierFlags) -> [String] {
        var parts: [String] = []
        if flags.contains(.control) { parts.append("Control") }
        if flags.contains(.option) { parts.append("Option") }
        if flags.contains(.shift) { parts.append("Shift") }
        if flags.contains(.command) { parts.append("Command") }
        return parts
    }
}

enum TranslateTriggerDecision {
    case passThrough
    case translate(SelectedTextContext)
    case showError(SelectionError)
}

struct SelectionError: LocalizedError {
    enum Kind {
        case unsupportedApp
        case emptySelection
        case missingFocusedElement
        case permissionDenied
    }

    let kind: Kind
    let fallbackRect: CGRect?

    var errorDescription: String? {
        switch kind {
        case .unsupportedApp:
            return "当前应用暂不支持读取选区，V1 已预留剪贴板兜底接口"
        case .emptySelection:
            return "当前没有选中文本"
        case .missingFocusedElement:
            return "未找到当前聚焦的输入控件"
        case .permissionDenied:
            return "缺少辅助功能权限"
        }
    }
}
