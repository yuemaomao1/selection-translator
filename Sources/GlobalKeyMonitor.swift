import AppKit
import ApplicationServices

final class GlobalKeyMonitor {
    private let onTranslateTrigger: () -> Bool
    private let onEscape: () -> Bool
    private let shouldHandleEscape: () -> Bool

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private static let keycodeEscape: CGKeyCode = 53
    private var triggerShortcut: TriggerShortcut

    init(
        triggerShortcut: TriggerShortcut,
        onTranslateTrigger: @escaping () -> Bool,
        onEscape: @escaping () -> Bool,
        shouldHandleEscape: @escaping () -> Bool
    ) {
        self.triggerShortcut = triggerShortcut
        self.onTranslateTrigger = onTranslateTrigger
        self.onEscape = onEscape
        self.shouldHandleEscape = shouldHandleEscape
    }

    func updateTriggerShortcut(_ triggerShortcut: TriggerShortcut) {
        self.triggerShortcut = triggerShortcut
    }

    func start() {
        guard eventTap == nil else { return }

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard type == .keyDown || type == .tapDisabledByTimeout || type == .tapDisabledByUserInput else {
                return Unmanaged.passUnretained(event)
            }

            let monitor = Unmanaged<GlobalKeyMonitor>.fromOpaque(refcon!).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = monitor.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            if monitor.shouldInterceptTranslate(event: event) {
                return monitor.onTranslateTrigger() ? nil : Unmanaged.passUnretained(event)
            }

            if monitor.shouldInterceptEscape(event: event) {
                let handled = monitor.onEscape()
                return handled ? nil : Unmanaged.passUnretained(event)
            }

            return Unmanaged.passUnretained(event)
        }

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1) << CGEventType.keyDown.rawValue,
            callback: callback,
            userInfo: refcon
        )

        guard let eventTap else { return }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        guard let runLoopSource else { return }

        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
    }

    private func shouldInterceptTranslate(event: CGEvent) -> Bool {
        guard let nsEvent = NSEvent(cgEvent: event),
              let shortcut = TriggerShortcut.from(event: nsEvent)
        else {
            return false
        }

        return shortcut == triggerShortcut
    }

    private func shouldInterceptEscape(event: CGEvent) -> Bool {
        guard shouldHandleEscape() else { return false }
        let keycode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        return keycode == Self.keycodeEscape
    }
}
