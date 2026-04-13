import AppKit

@MainActor
final class AppCoordinator {
    private let permissionService = PermissionService()
    private let preferences = AppPreferences()
    private let selectionService = AccessibilitySelectionService()
    private let clipboardFallbackService = ClipboardFallbackService()
    private let translationService = SystemTranslationService()
    private let panelController = TranslationPanelController()

    private var statusBarController: StatusBarController?
    private var settingsWindowController: SettingsWindowController?
    private var keyMonitor: GlobalKeyMonitor?

    func start() {
        statusBarController = StatusBarController(
            onOpenSettings: { [weak self] in
                self?.showSettingsWindow()
            },
            onOpenAccessibilitySettings: { [weak self] in
                self?.permissionService.openAccessibilitySettings()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        settingsWindowController = SettingsWindowController(
            permissionService: permissionService,
            preferences: preferences,
            onAppearanceChanged: { [weak self] panelWidth, fontSize in
                self?.panelController.applyAppearance(panelWidth: panelWidth, fontSize: fontSize)
            },
            onTriggerKeyChanged: { [weak self] shortcut in
                self?.keyMonitor?.updateTriggerShortcut(shortcut)
            },
            onAutoDismissChanged: { [weak self] seconds in
                self?.panelController.applyBehavior(autoDismissSeconds: seconds)
            }
        )
        panelController.applyAppearance(
            panelWidth: preferences.panelWidth,
            fontSize: preferences.translationFontSize
        )
        panelController.applyBehavior(autoDismissSeconds: preferences.autoDismissSeconds)

        if !permissionService.isAccessibilityTrusted(promptIfNeeded: true) {
            panelController.showFailure(
                message: "请先授予辅助功能权限",
                near: selectionService.mouseFallbackRect()
            )
        }

        keyMonitor = GlobalKeyMonitor(
            triggerShortcut: preferences.triggerShortcut,
            onTranslateTrigger: { [weak self] in
                self?.handleTranslateTrigger() ?? false
            },
            onEscape: { [weak self] in
                self?.panelController.close()
                return true
            },
            shouldHandleEscape: { [weak self] in
                self?.panelController.isVisible ?? false
            }
        )
        keyMonitor?.start()
    }

    func stop() {
        keyMonitor?.stop()
    }

    private func handleTranslateTrigger() -> Bool {
        switch selectionService.decisionForTrigger() {
        case .translate(let selection):
            panelController.showLoading(near: selection.anchorRect)

            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let translated = try await translationService.translate(text: selection.text)
                    panelController.showSuccess(
                        original: selection.text,
                        translated: translated,
                        near: selection.anchorRect
                    )
                } catch {
                    panelController.showFailure(
                        message: error.localizedDescription,
                        near: selection.anchorRect
                    )
                }
            }
            return true
        case .showError(let error):
            if error.kind == .unsupportedApp, preferences.clipboardFallbackEnabled {
                let fallbackAnchor = error.fallbackRect ?? selectionService.mouseFallbackRect()
                panelController.showLoading(near: fallbackAnchor)

                switch clipboardFallbackService.captureSelectedTextViaCopyShortcut() {
                case .success(let text):
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        do {
                            let translated = try await translationService.translate(text: text)
                            panelController.showSuccess(
                                original: text,
                                translated: translated,
                                near: fallbackAnchor
                            )
                        } catch {
                            panelController.showFailure(
                                message: error.localizedDescription,
                                near: fallbackAnchor
                            )
                        }
                    }
                    return true
                case .failure(let fallbackError):
                    panelController.showFailure(
                        message: "\(error.localizedDescription)\n\(fallbackError.localizedDescription)",
                        near: fallbackAnchor
                    )
                    return true
                }
            }

            panelController.showFailure(
                message: error.localizedDescription,
                near: error.fallbackRect ?? selectionService.mouseFallbackRect()
            )
            return true
        case .passThrough:
            return false
        }
    }

    private func showSettingsWindow() {
        settingsWindowController?.showWindowAndActivate()
    }
}
