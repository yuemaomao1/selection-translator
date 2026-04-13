import AppKit
import Testing
@testable import SelectionTranslator

struct TriggerShortcutTests {
    @Test
    func displayNameIncludesModifiersInStableOrder() {
        let shortcut = TriggerShortcut(
            key: "space",
            modifiers: [.command, .option, .control]
        )

        #expect(shortcut.displayName == "Control+Option+Command+Space")
    }

    @Test
    func normalizedKeyTokenAcceptsLettersDigitsAndSpace() {
        #expect(TriggerShortcut.normalizedKeyToken(from: "T") == "t")
        #expect(TriggerShortcut.normalizedKeyToken(from: "7") == "7")
        #expect(TriggerShortcut.normalizedKeyToken(from: " ") == "space")
    }

    @Test
    func normalizedKeyTokenRejectsUnsupportedKeys() {
        #expect(TriggerShortcut.normalizedKeyToken(from: "\n") == nil)
        #expect(TriggerShortcut.normalizedKeyToken(from: "-") == nil)
        #expect(TriggerShortcut.normalizedKeyToken(from: "") == nil)
    }

    @Test
    func normalizedModifiersKeepsOnlySupportedModifierFlags() {
        let normalized = TriggerShortcut.normalizedModifiers([.command, .shift, .capsLock, .numericPad])

        #expect(normalized.contains(.command))
        #expect(normalized.contains(.shift))
        #expect(!normalized.contains(.capsLock))
        #expect(!normalized.contains(.numericPad))
    }
}
