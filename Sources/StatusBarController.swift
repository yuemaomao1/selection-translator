import AppKit

final class StatusBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let onOpenSettings: () -> Void
    private let onOpenAccessibilitySettings: () -> Void
    private let onQuit: () -> Void
    
    init(onOpenSettings: @escaping () -> Void, onOpenAccessibilitySettings: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onOpenSettings = onOpenSettings
        self.onOpenAccessibilitySettings = onOpenAccessibilitySettings
        self.onQuit = onQuit
        configure()
    }

    private func configure() {
        if let button = statusItem.button {
            button.title = "译"
            button.toolTip = "全局划词翻译"
        }

        let menu = NSMenu()
        menu.addItem(
            withTitle: "设置…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        menu.addItem(
            withTitle: "打开辅助功能设置",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "退出",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    @objc
    private func openSettings() {
        onOpenSettings()
    }

    @objc
    private func openAccessibilitySettings() {
        onOpenAccessibilitySettings()
    }

    @objc
    private func quit() {
        onQuit()
    }
}
