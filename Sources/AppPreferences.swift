import AppKit
import Foundation

@MainActor
final class AppPreferences {
    private enum Keys {
        static let clipboardFallbackEnabled = "clipboardFallbackEnabled"
        static let panelWidth = "panelWidth"
        static let translationFontSize = "translationFontSize"
        static let triggerKey = "triggerKey"
        static let triggerModifiers = "triggerModifiers"
        static let autoDismissSeconds = "autoDismissSeconds"
    }

    private let userDefaults: UserDefaults
    static let defaultPanelWidth: Double = 320
    static let minPanelWidth: Double = 280
    static let maxPanelWidth: Double = 520
    static let defaultTranslationFontSize: Double = 14
    static let minTranslationFontSize: Double = 12
    static let maxTranslationFontSize: Double = 22
    static let autoDismissOptions: [Double] = [0, 5, 10, 20]

    var clipboardFallbackEnabled: Bool
    var panelWidth: Double
    var translationFontSize: Double
    var triggerShortcut: TriggerShortcut
    var autoDismissSeconds: Double

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.clipboardFallbackEnabled = userDefaults.bool(forKey: Keys.clipboardFallbackEnabled)
        let storedPanelWidth = userDefaults.object(forKey: Keys.panelWidth) as? Double ?? Self.defaultPanelWidth
        self.panelWidth = Self.clamp(storedPanelWidth, min: Self.minPanelWidth, max: Self.maxPanelWidth)
        let storedFontSize = userDefaults.object(forKey: Keys.translationFontSize) as? Double ?? Self.defaultTranslationFontSize
        self.translationFontSize = Self.clamp(storedFontSize, min: Self.minTranslationFontSize, max: Self.maxTranslationFontSize)
        let storedTriggerKey = userDefaults.string(forKey: Keys.triggerKey) ?? TriggerShortcut.defaultShortcut.key
        let storedTriggerModifiers = userDefaults.object(forKey: Keys.triggerModifiers) as? UInt ?? TriggerShortcut.defaultShortcut.modifiers.rawValue
        self.triggerShortcut = Self.normalizedShortcut(
            TriggerShortcut(key: storedTriggerKey, modifiers: NSEvent.ModifierFlags(rawValue: storedTriggerModifiers))
        )
        let storedAutoDismiss = userDefaults.object(forKey: Keys.autoDismissSeconds) as? Double ?? 10
        self.autoDismissSeconds = Self.normalizedAutoDismissSeconds(storedAutoDismiss)
    }

    func setClipboardFallbackEnabled(_ enabled: Bool) {
        clipboardFallbackEnabled = enabled
        userDefaults.set(enabled, forKey: Keys.clipboardFallbackEnabled)
    }

    func setPanelWidth(_ width: Double) {
        let normalized = Self.clamp(width, min: Self.minPanelWidth, max: Self.maxPanelWidth)
        panelWidth = normalized
        userDefaults.set(normalized, forKey: Keys.panelWidth)
    }

    func setTranslationFontSize(_ size: Double) {
        let normalized = Self.clamp(size, min: Self.minTranslationFontSize, max: Self.maxTranslationFontSize)
        translationFontSize = normalized
        userDefaults.set(normalized, forKey: Keys.translationFontSize)
    }

    func resetAppearanceToDefaults() {
        setPanelWidth(Self.defaultPanelWidth)
        setTranslationFontSize(Self.defaultTranslationFontSize)
    }

    func setTriggerShortcut(_ shortcut: TriggerShortcut) {
        let normalized = Self.normalizedShortcut(shortcut)
        triggerShortcut = normalized
        userDefaults.set(normalized.key, forKey: Keys.triggerKey)
        userDefaults.set(normalized.modifiers.rawValue, forKey: Keys.triggerModifiers)
    }

    func setAutoDismissSeconds(_ seconds: Double) {
        let normalized = Self.normalizedAutoDismissSeconds(seconds)
        autoDismissSeconds = normalized
        userDefaults.set(normalized, forKey: Keys.autoDismissSeconds)
    }

    private static func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.max(min, Swift.min(max, value))
    }

    private static func normalizedShortcut(_ shortcut: TriggerShortcut) -> TriggerShortcut {
        let normalizedKey: String
        if shortcut.key == "space" {
            normalizedKey = "space"
        } else {
            normalizedKey = TriggerShortcut.normalizedKeyToken(from: shortcut.key) ?? TriggerShortcut.defaultShortcut.key
        }
        let normalizedModifiers = TriggerShortcut.normalizedModifiers(shortcut.modifiers)
        return TriggerShortcut(key: normalizedKey, modifiers: normalizedModifiers)
    }

    private static func normalizedAutoDismissSeconds(_ seconds: Double) -> Double {
        autoDismissOptions.contains(seconds) ? seconds : 10
    }
}
