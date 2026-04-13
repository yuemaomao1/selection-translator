import AppKit
import Foundation
import Testing
@testable import SelectionTranslator

struct AppPreferencesTests {
    @Test
    @MainActor
    func initializesWithNormalizedPersistedValues() {
        let (defaults, suiteName) = makeDefaults()
        defaults.set(900.0, forKey: "panelWidth")
        defaults.set(2.0, forKey: "translationFontSize")
        defaults.set("-", forKey: "triggerKey")
        defaults.set(NSEvent.ModifierFlags.command.rawValue, forKey: "triggerModifiers")
        defaults.set(123.0, forKey: "autoDismissSeconds")

        let preferences = AppPreferences(userDefaults: defaults)

        #expect(preferences.panelWidth == AppPreferences.maxPanelWidth)
        #expect(preferences.translationFontSize == AppPreferences.minTranslationFontSize)
        #expect(preferences.triggerShortcut == TriggerShortcut(key: "t", modifiers: .command))
        #expect(preferences.autoDismissSeconds == 10)
        reset(defaults, suiteName: suiteName)
    }

    @Test
    @MainActor
    func setterMethodsPersistValues() {
        let (defaults, suiteName) = makeDefaults()
        let preferences = AppPreferences(userDefaults: defaults)
        let shortcut = TriggerShortcut(key: "space", modifiers: [.option, .shift])

        preferences.setClipboardFallbackEnabled(true)
        preferences.setPanelWidth(410)
        preferences.setTranslationFontSize(18)
        preferences.setTriggerShortcut(shortcut)
        preferences.setAutoDismissSeconds(20)

        let reloaded = AppPreferences(userDefaults: defaults)
        #expect(reloaded.clipboardFallbackEnabled)
        #expect(reloaded.panelWidth == 410)
        #expect(reloaded.translationFontSize == 18)
        #expect(reloaded.triggerShortcut == shortcut)
        #expect(reloaded.autoDismissSeconds == 20)
        reset(defaults, suiteName: suiteName)
    }

    @Test
    @MainActor
    func resetAppearanceRestoresDefaultsOnlyForAppearance() {
        let (defaults, suiteName) = makeDefaults()
        let preferences = AppPreferences(userDefaults: defaults)

        preferences.setPanelWidth(480)
        preferences.setTranslationFontSize(20)
        preferences.setTriggerShortcut(TriggerShortcut(key: "9", modifiers: [.control]))
        preferences.resetAppearanceToDefaults()

        #expect(preferences.panelWidth == AppPreferences.defaultPanelWidth)
        #expect(preferences.translationFontSize == AppPreferences.defaultTranslationFontSize)
        #expect(preferences.triggerShortcut == TriggerShortcut(key: "9", modifiers: [.control]))
        reset(defaults, suiteName: suiteName)
    }

    @MainActor
    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "SelectionTranslatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    @MainActor
    private func reset(_ defaults: UserDefaults, suiteName: String) {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
