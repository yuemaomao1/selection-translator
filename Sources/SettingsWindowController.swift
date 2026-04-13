import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    private let permissionService: PermissionService
    private let preferences: AppPreferences
    private let launchAtLoginService = LaunchAtLoginService()
    private let onAppearanceChanged: (Double, Double) -> Void
    private let onTriggerShortcutChanged: (TriggerShortcut) -> Void
    private let onAutoDismissChanged: (Double) -> Void

    private let accessibilityStatusLabel = NSTextField(labelWithString: "")
    private let translationStatusLabel = NSTextField(labelWithString: "")
    private let launchAtLoginStatusLabel = NSTextField(labelWithString: "")
    private let clipboardCheckbox = NSButton(checkboxWithTitle: "启用剪贴板兜底（会短暂占用并恢复系统剪贴板）", target: nil, action: nil)
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "登录时启动（仅对签名后的 .app 生效）", target: nil, action: nil)
    private let panelWidthValueLabel = NSTextField(labelWithString: "")
    private let fontSizeValueLabel = NSTextField(labelWithString: "")
    private let autoDismissPopup = NSPopUpButton()
    private let shortcutValueLabel = NSTextField(labelWithString: "")
    private let shortcutRecordButton = NSButton(title: "录制快捷键", target: nil, action: nil)
    private let shortcutResetButton = NSButton(title: "恢复默认", target: nil, action: nil)
    private let panelWidthSlider = NSSlider(value: AppPreferences.defaultPanelWidth, minValue: AppPreferences.minPanelWidth, maxValue: AppPreferences.maxPanelWidth, target: nil, action: nil)
    private let fontSizeSlider = NSSlider(value: AppPreferences.defaultTranslationFontSize, minValue: AppPreferences.minTranslationFontSize, maxValue: AppPreferences.maxTranslationFontSize, target: nil, action: nil)
    private let resetAppearanceButton = NSButton(title: "恢复默认外观", target: nil, action: nil)
    private var shortcutRecorderMonitor: Any?
    private var isRecordingShortcut = false

    init(
        permissionService: PermissionService,
        preferences: AppPreferences,
        onAppearanceChanged: @escaping (Double, Double) -> Void,
        onTriggerKeyChanged: @escaping (TriggerShortcut) -> Void,
        onAutoDismissChanged: @escaping (Double) -> Void
    ) {
        self.permissionService = permissionService
        self.preferences = preferences
        self.onAppearanceChanged = onAppearanceChanged
        self.onTriggerShortcutChanged = onTriggerKeyChanged
        self.onAutoDismissChanged = onAutoDismissChanged

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "设置"
        window.center()
        super.init(window: window)
        configureUI()
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindowAndActivate() {
        refresh()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureUI() {
        guard let contentView = window?.contentView else { return }

        let titleLabel = NSTextField(labelWithString: "全局划词翻译")
        titleLabel.font = .boldSystemFont(ofSize: 22)

        let tipsLabel = NSTextField(wrappingLabelWithString: "V1 优先覆盖大多数标准文本选择场景。若某些应用无法直接读取选区，可按需开启剪贴板兜底。系统翻译依赖 macOS 15+。")
        tipsLabel.textColor = .secondaryLabelColor

        accessibilityStatusLabel.font = .systemFont(ofSize: 13)
        translationStatusLabel.font = .systemFont(ofSize: 13)
        launchAtLoginStatusLabel.font = .systemFont(ofSize: 13)
        launchAtLoginStatusLabel.textColor = .secondaryLabelColor

        clipboardCheckbox.target = self
        clipboardCheckbox.action = #selector(toggleClipboardFallback)
        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(toggleLaunchAtLogin)

        panelWidthSlider.target = self
        panelWidthSlider.action = #selector(changePanelWidth)
        fontSizeSlider.target = self
        fontSizeSlider.action = #selector(changeFontSize)
        autoDismissPopup.target = self
        autoDismissPopup.action = #selector(changeAutoDismiss)
        shortcutRecordButton.target = self
        shortcutRecordButton.action = #selector(toggleShortcutRecording)
        shortcutResetButton.target = self
        shortcutResetButton.action = #selector(resetShortcut)
        resetAppearanceButton.target = self
        resetAppearanceButton.action = #selector(resetAppearance)
        shortcutValueLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        shortcutValueLabel.textColor = .secondaryLabelColor
        autoDismissPopup.addItems(withTitles: ["不自动关闭", "5 秒", "10 秒", "20 秒"])

        let panelWidthRow = labeledRow(label: "浮窗宽度", control: panelWidthSlider, valueLabel: panelWidthValueLabel)
        let fontSizeRow = labeledRow(label: "译文字号", control: fontSizeSlider, valueLabel: fontSizeValueLabel)
        let autoDismissRow = labeledRow(label: "自动关闭", control: autoDismissPopup, valueLabel: NSTextField(labelWithString: ""))
        let shortcutRow = shortcutRowView()

        let openAccessibilityButton = NSButton(title: "打开辅助功能设置", target: self, action: #selector(openAccessibilitySettings))
        let openLoginItemsButton = NSButton(title: "打开系统登录项设置", target: self, action: #selector(openLoginItemsSettings))
        let refreshButton = NSButton(title: "刷新状态", target: self, action: #selector(refreshStatus))

        let appearanceCard = makeCard(
            title: "外观",
            subtitle: "控制翻译浮窗的尺寸与阅读体验",
            contentViews: [
                panelWidthRow,
                fontSizeRow,
                autoDismissRow,
                buttonRow(buttons: [resetAppearanceButton])
            ]
        )
        let compatibilityCard = makeCard(
            title: "兼容性",
            subtitle: "控制选区读取失败时的兜底策略",
            contentViews: [
                shortcutRow,
                clipboardCheckbox,
                helpLabel("点击“录制快捷键”后按下一组组合键，例如 Option+T 或 Control+Space。"),
                helpLabel("剪贴板兜底会模拟一次 Cmd+C，读取完成后恢复原剪贴板内容。")
            ]
        )
        let systemCard = makeCard(
            title: "系统集成",
            subtitle: "查看权限、翻译能力与登录项状态",
            contentViews: [
                accessibilityStatusLabel,
                translationStatusLabel,
                launchAtLoginCheckbox,
                launchAtLoginStatusLabel,
                buttonRow(buttons: [openAccessibilityButton, openLoginItemsButton, refreshButton])
            ]
        )

        let stack = NSStackView(views: [
            titleLabel,
            tipsLabel,
            appearanceCard,
            compatibilityCard,
            systemCard
        ])
        stack.orientation = .vertical
        stack.spacing = 18
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -24)
        ])
    }

    private func refresh() {
        let accessibilityGranted = permissionService.isAccessibilityTrusted(promptIfNeeded: false)
        accessibilityStatusLabel.stringValue = "辅助功能权限：\(accessibilityGranted ? "已授权" : "未授权")"
        translationStatusLabel.stringValue = "系统翻译能力：\(permissionService.isSystemTranslationAvailable ? "可用" : "需 macOS 15 或更高版本")"
        clipboardCheckbox.state = preferences.clipboardFallbackEnabled ? .on : .off
        panelWidthSlider.doubleValue = preferences.panelWidth
        fontSizeSlider.doubleValue = preferences.translationFontSize
        panelWidthValueLabel.stringValue = "\(Int(preferences.panelWidth)) pt"
        fontSizeValueLabel.stringValue = String(format: "%.0f pt", preferences.translationFontSize)
        autoDismissPopup.selectItem(at: AppPreferences.autoDismissOptions.firstIndex(of: preferences.autoDismissSeconds) ?? 2)
        shortcutValueLabel.stringValue = preferences.triggerShortcut.displayName
        shortcutRecordButton.title = isRecordingShortcut ? "按下快捷键…" : "录制快捷键"
        launchAtLoginCheckbox.state = launchAtLoginService.isEnabled ? .on : .off
        launchAtLoginStatusLabel.stringValue = "登录时启动状态：\(launchAtLoginService.statusDescription)"
    }

    @objc
    private func toggleClipboardFallback() {
        preferences.setClipboardFallbackEnabled(clipboardCheckbox.state == .on)
    }

    @objc
    private func toggleLaunchAtLogin() {
        let shouldEnable = (launchAtLoginCheckbox.state == .on)
        do {
            try launchAtLoginService.setEnabled(shouldEnable)
        } catch {
            launchAtLoginCheckbox.state = launchAtLoginService.isEnabled ? .on : .off
            NSSound.beep()
        }
        refresh()
    }

    @objc
    private func changePanelWidth() {
        preferences.setPanelWidth(panelWidthSlider.doubleValue)
        panelWidthValueLabel.stringValue = "\(Int(preferences.panelWidth)) pt"
        onAppearanceChanged(preferences.panelWidth, preferences.translationFontSize)
    }

    @objc
    private func changeFontSize() {
        preferences.setTranslationFontSize(fontSizeSlider.doubleValue)
        fontSizeValueLabel.stringValue = String(format: "%.0f pt", preferences.translationFontSize)
        onAppearanceChanged(preferences.panelWidth, preferences.translationFontSize)
    }

    @objc
    private func changeAutoDismiss() {
        let index = max(0, autoDismissPopup.indexOfSelectedItem)
        let seconds = AppPreferences.autoDismissOptions[index]
        preferences.setAutoDismissSeconds(seconds)
        onAutoDismissChanged(preferences.autoDismissSeconds)
    }

    @objc
    private func toggleShortcutRecording() {
        if isRecordingShortcut {
            stopShortcutRecording()
            refresh()
            return
        }

        isRecordingShortcut = true
        shortcutRecorderMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isRecordingShortcut else { return event }

            if event.keyCode == 53 {
                self.stopShortcutRecording()
                self.refresh()
                return nil
            }

            guard let shortcut = TriggerShortcut.from(event: event) else {
                NSSound.beep()
                return nil
            }

            self.preferences.setTriggerShortcut(shortcut)
            self.onTriggerShortcutChanged(self.preferences.triggerShortcut)
            self.stopShortcutRecording()
            self.refresh()
            return nil
        }
        refresh()
    }

    @objc
    private func resetShortcut() {
        preferences.setTriggerShortcut(.defaultShortcut)
        onTriggerShortcutChanged(preferences.triggerShortcut)
        stopShortcutRecording()
        refresh()
    }

    @objc
    private func resetAppearance() {
        preferences.resetAppearanceToDefaults()
        panelWidthSlider.doubleValue = preferences.panelWidth
        fontSizeSlider.doubleValue = preferences.translationFontSize
        panelWidthValueLabel.stringValue = "\(Int(preferences.panelWidth)) pt"
        fontSizeValueLabel.stringValue = String(format: "%.0f pt", preferences.translationFontSize)
        onAppearanceChanged(preferences.panelWidth, preferences.translationFontSize)
    }

    @objc
    private func openAccessibilitySettings() {
        permissionService.openAccessibilitySettings()
    }

    @objc
    private func openLoginItemsSettings() {
        launchAtLoginService.openSystemSettings()
    }

    @objc
    private func refreshStatus() {
        refresh()
    }

    private func stopShortcutRecording() {
        isRecordingShortcut = false
        if let shortcutRecorderMonitor {
            NSEvent.removeMonitor(shortcutRecorderMonitor)
        }
        shortcutRecorderMonitor = nil
    }

    private func labeledRow(label: String, control: NSControl, valueLabel: NSTextField) -> NSView {
        let titleLabel = NSTextField(labelWithString: label)
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        valueLabel.alignment = .right
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)

        let row = NSStackView(views: [titleLabel, control, valueLabel])
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY

        control.translatesAutoresizingMaskIntoConstraints = false
        let controlWidth: CGFloat = control is NSPopUpButton ? 160 : 260
        control.widthAnchor.constraint(equalToConstant: controlWidth).isActive = true
        valueLabel.widthAnchor.constraint(equalToConstant: 64).isActive = true

        return row
    }

    private func shortcutRowView() -> NSView {
        let titleLabel = NSTextField(labelWithString: "触发快捷键")
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)

        let buttons = buttonRow(buttons: [shortcutRecordButton, shortcutResetButton])
        let row = NSStackView(views: [titleLabel, shortcutValueLabel, buttons])
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY

        shortcutValueLabel.widthAnchor.constraint(equalToConstant: 140).isActive = true

        return row
    }

    private func buttonRow(buttons: [NSButton]) -> NSView {
        let row = NSStackView(views: buttons)
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        return row
    }

    private func helpLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func makeCard(title: String, subtitle: String, contentViews: [NSView]) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 14
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.blended(withFraction: 0.35, of: .controlBackgroundColor)?.cgColor
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .boldSystemFont(ofSize: 14)

        let subtitleLabel = NSTextField(wrappingLabelWithString: subtitle)
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [titleLabel, subtitleLabel] + contentViews)
        stack.orientation = .vertical
        stack.spacing = 10
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            container.widthAnchor.constraint(equalToConstant: 572)
        ])

        return container
    }
}
