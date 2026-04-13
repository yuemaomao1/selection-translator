import AppKit

@MainActor
final class TranslationPanelController: NSObject {
    private enum DisplayMode {
        case original
        case translated
    }

    private enum Layout {
        static let minHeight: CGFloat = 140
        static let topInset: CGFloat = 16
        static let bottomInset: CGFloat = 16
        static let sideInset: CGFloat = 16
        static let spinnerSize: CGFloat = 16
        static let headerHeight: CGFloat = 24
        static let buttonWidth: CGFloat = 60
        static let buttonHeight: CGFloat = 24
        static let pinButtonWidth: CGFloat = 72
        static let toggleWidth: CGFloat = 116
        static let contentSpacing: CGFloat = 8
    }

    private let panel = FloatingPanel()
    private let spinner = NSProgressIndicator()
    private let textView = NSTextView()
    private let copyButton = NSButton(title: "复制", target: nil, action: nil)
    private let pinButton = NSButton(title: "固定", target: nil, action: nil)
    private let toggleControl = NSSegmentedControl(labels: ["译文", "原文"], trackingMode: .selectOne, target: nil, action: nil)
    private let visualEffect = NSVisualEffectView()
    private let scrollView = NSScrollView()
    private var outsideClickMonitor: Any?
    private var preferredPanelWidth: CGFloat = CGFloat(AppPreferences.defaultPanelWidth)
    private var preferredFontSize: CGFloat = CGFloat(AppPreferences.defaultTranslationFontSize)
    private var isPinned = false
    private var autoDismissSeconds: Double = 10
    private var displayMode: DisplayMode = .translated
    private var originalText: String?
    private var translatedText: String?
    private var autoDismissTask: Task<Void, Never>?

    var isVisible: Bool {
        panel.isVisible
    }

    override init() {
        super.init()
        configurePanel()
        configureOutsideClickMonitor()
    }

    func applyAppearance(panelWidth: Double, fontSize: Double) {
        preferredPanelWidth = CGFloat(panelWidth)
        preferredFontSize = CGFloat(fontSize)
        textView.font = .systemFont(ofSize: preferredFontSize)
        layoutPanel(forText: textView.string)
    }

    func applyBehavior(autoDismissSeconds: Double) {
        self.autoDismissSeconds = autoDismissSeconds
        rescheduleAutoDismissIfNeeded()
    }

    func showLoading(near anchorRect: CGRect) {
        prepareForPresentation()
        originalText = nil
        translatedText = nil
        displayMode = .translated
        spinner.startAnimation(nil)
        copyButton.isHidden = true
        toggleControl.isHidden = true
        textView.string = "正在翻译…"
        cancelAutoDismiss()
        showPanel(near: anchorRect)
    }

    func showSuccess(original: String, translated: String, near anchorRect: CGRect) {
        prepareForPresentation()
        originalText = original
        translatedText = translated
        displayMode = .translated
        spinner.stopAnimation(nil)
        copyButton.isHidden = false
        toggleControl.isHidden = false
        toggleControl.selectedSegment = 0
        textView.string = translated
        showPanel(near: anchorRect)
        scheduleAutoDismissIfNeeded()
    }

    func showFailure(message: String, near anchorRect: CGRect) {
        prepareForPresentation()
        originalText = nil
        translatedText = nil
        displayMode = .translated
        spinner.stopAnimation(nil)
        copyButton.isHidden = true
        toggleControl.isHidden = true
        textView.string = message
        showPanel(near: anchorRect)
        scheduleAutoDismissIfNeeded()
    }

    func close() {
        cancelAutoDismiss()
        isPinned = false
        updatePinButton()
        panel.isMovableByWindowBackground = false
        panel.orderOut(nil)
    }

    private func configurePanel() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: preferredPanelWidth, height: Layout.minHeight))
        panel.contentView = contentView

        visualEffect.frame = contentView.bounds
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.blendingMode = .behindWindow
        visualEffect.material = .popover
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        contentView.addSubview(visualEffect)

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.frame = NSRect(x: Layout.sideInset, y: 0, width: Layout.spinnerSize, height: Layout.spinnerSize)
        visualEffect.addSubview(spinner)

        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        visualEffect.addSubview(scrollView)

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: preferredFontSize)
        textView.textContainerInset = NSSize(width: 0, height: 4)
        scrollView.documentView = textView

        copyButton.bezelStyle = .rounded
        copyButton.target = self
        copyButton.action = #selector(copyTranslation)
        copyButton.isHidden = true
        visualEffect.addSubview(copyButton)

        pinButton.bezelStyle = .rounded
        pinButton.target = self
        pinButton.action = #selector(togglePinned)
        visualEffect.addSubview(pinButton)

        toggleControl.target = self
        toggleControl.action = #selector(toggleDisplayedText)
        toggleControl.selectedSegment = 0
        toggleControl.isHidden = true
        visualEffect.addSubview(toggleControl)

        layoutPanel(forText: "")
    }

    private func configureOutsideClickMonitor() {
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.panel.isVisible else { return }
            guard !self.isPinned else { return }
            let point = event.locationInWindow
            if !self.panel.frame.contains(point) {
                DispatchQueue.main.async {
                    self.close()
                }
            }
        }
    }

    private func showPanel(near anchorRect: CGRect) {
        layoutPanel(forText: textView.string)
        let panelSize = panel.frame.size
        let frame = FloatingPanelPlacer.place(panelSize: panelSize, around: anchorRect)
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    private func layoutPanel(forText text: String) {
        let width = preferredPanelWidth
        let textAreaWidth = width - Layout.sideInset * 2
        let measuredTextHeight = measureTextHeight(text: text, width: textAreaWidth)
        let scrollHeight = max(84, min(220, measuredTextHeight + 8))
        let totalHeight = max(
            Layout.minHeight,
            Layout.topInset + Layout.headerHeight + Layout.contentSpacing + scrollHeight + Layout.bottomInset
        )

        panel.setContentSize(NSSize(width: width, height: totalHeight))
        panel.contentView?.frame = NSRect(x: 0, y: 0, width: width, height: totalHeight)
        visualEffect.frame = NSRect(x: 0, y: 0, width: width, height: totalHeight)

        let headerY = totalHeight - Layout.topInset - Layout.headerHeight
        spinner.frame = NSRect(
            x: Layout.sideInset,
            y: headerY + (Layout.headerHeight - Layout.spinnerSize) / 2,
            width: Layout.spinnerSize,
            height: Layout.spinnerSize
        )
        copyButton.frame = NSRect(
            x: width - Layout.sideInset - Layout.buttonWidth,
            y: headerY,
            width: Layout.buttonWidth,
            height: Layout.buttonHeight
        )
        pinButton.frame = NSRect(
            x: copyButton.frame.minX - 8 - Layout.pinButtonWidth,
            y: headerY,
            width: Layout.pinButtonWidth,
            height: Layout.buttonHeight
        )
        toggleControl.frame = NSRect(
            x: pinButton.frame.minX - 8 - Layout.toggleWidth,
            y: headerY,
            width: Layout.toggleWidth,
            height: Layout.buttonHeight
        )
        scrollView.frame = NSRect(
            x: Layout.sideInset,
            y: Layout.bottomInset,
            width: textAreaWidth,
            height: scrollHeight
        )
        textView.frame = NSRect(x: 0, y: 0, width: textAreaWidth, height: measuredTextHeight + 12)
    }

    private func measureTextHeight(text: String, width: CGFloat) -> CGFloat {
        let content = text.isEmpty ? " " : text
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: preferredFontSize)
        ]
        let rect = (content as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        return ceil(rect.height)
    }

    @objc
    private func copyTranslation() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(textView.string, forType: .string)
    }

    @objc
    private func togglePinned() {
        isPinned.toggle()
        updatePinButton()
        panel.isMovableByWindowBackground = isPinned
        rescheduleAutoDismissIfNeeded()
    }

    private func prepareForPresentation() {
        updatePinButton()
        panel.isMovableByWindowBackground = isPinned
    }

    private func updatePinButton() {
        pinButton.title = isPinned ? "取消固定" : "固定"
    }

    @objc
    private func toggleDisplayedText() {
        guard let originalText, let translatedText else { return }

        displayMode = toggleControl.selectedSegment == 1 ? .original : .translated
        textView.string = (displayMode == .original) ? originalText : translatedText
        layoutPanel(forText: textView.string)
        rescheduleAutoDismissIfNeeded()
    }

    private func scheduleAutoDismissIfNeeded() {
        guard autoDismissSeconds > 0, !isPinned else { return }
        cancelAutoDismiss()
        autoDismissTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(autoDismissSeconds * 1_000_000_000))
            guard !Task.isCancelled, !isPinned else { return }
            close()
        }
    }

    private func cancelAutoDismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
    }

    private func rescheduleAutoDismissIfNeeded() {
        cancelAutoDismiss()
        if panel.isVisible {
            scheduleAutoDismissIfNeeded()
        }
    }
}

final class FloatingPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: AppPreferences.defaultPanelWidth, height: 140),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isOpaque = false
        hasShadow = true
        backgroundColor = .clear
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
