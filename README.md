# SelectionTranslator

A macOS menu bar translator for global text selection.

Current capabilities:

- checks Accessibility permission
- listens for a configurable global shortcut
- reads selected text and selection bounds via Accessibility APIs
- shows a non-overlapping floating panel near the selection
- translates EN -> ZH and ZH -> EN through Apple's system Translation framework on macOS 15+
- optionally falls back to clipboard copy when some apps do not expose AX selected text
- supports loading / success / failure panel states
- supports `Esc` close, outside click close, pin/unpin, copy result, original/translation toggle
- supports configurable panel width, font size, auto-dismiss time, and launch-at-login integration

## Requirements

- macOS 13+ to run the app shell
- macOS 15+ to use Apple's system Translation framework
- Accessibility permission for global shortcut interception and AX selection reads
- Full Xcode is recommended for signing, login-item validation, and shipping a `.app`

## Development Run

Run the app in place:

```bash
swift run
```

Then:

1. Grant Accessibility permission when prompted.
2. Select text in a normal macOS text control.
3. Press the configured shortcut.
4. Confirm the floating panel appears near the selection and does not overlap the original selection.

Run tests:

```bash
swift test
```

## Usage Notes

- Open settings from the menu bar icon: `设置…`
- The default shortcut is `T`
- You can record a real shortcut such as `Option+T` or `Control+Space`
- Clipboard fallback is off by default because it briefly sends `Cmd+C` and then restores the clipboard
- Pinning the panel keeps it open and allows dragging it
- Auto-dismiss can be disabled or set to `5 / 10 / 20` seconds

## What Is Covered In V1

- Standard AppKit and many common macOS text fields / text views
- AX-based selected text reads via:
  - `kAXSelectedTextAttribute`
  - `kAXSelectedTextRangeAttribute`
  - `kAXBoundsForRangeParameterizedAttribute`
- Fallback to mouse-near placement when selection bounds are unavailable
- Fallback messaging when selected text is unavailable

## Known Limitations

- Some apps expose selection text but not reliable bounds, so panel placement may fall back near the mouse
- Some apps do not expose selection text through Accessibility at all; clipboard fallback helps but is not universal
- Launch-at-login is most meaningful when running a signed `.app` bundle, not `swift run`
- The current shortcut recorder is intentionally conservative and only records displayable key combinations, not every possible special key

## Project Structure

```text
Sources/
  AppCoordinator.swift
  AccessibilitySelectionService.swift
  GlobalKeyMonitor.swift
  TranslationPanelController.swift
  TranslationService.swift
  SettingsWindowController.swift
  ...
Tests/
  TriggerShortcutTests.swift
  AppPreferencesTests.swift
Xcode/
  Info.plist
  Debug.xcconfig
  Release.xcconfig
  SelectionTranslator.entitlements
SelectionTranslator.xcodeproj/
```

## Settings

- Menu bar icon -> `设置…`
- Appearance:
  - panel width
  - translation font size
  - auto-dismiss timeout
- Compatibility:
  - shortcut recording
  - clipboard fallback
- System:
  - Accessibility status
  - Translation availability status
  - launch-at-login toggle

## Validation Checklist

- `swift build`
- `swift test`
- Select English text -> shows Chinese translation
- Select Chinese text -> shows English translation
- No selection -> shortcut passes through to the foreground app
- Selection present -> shortcut is intercepted and not typed into the foreground app
- `Esc` closes the panel
- Outside click closes when not pinned
- Pinned panel stays open and can be dragged
- Copy button copies visible text
- Original / translation toggle switches content correctly

## Xcode

- A native app target scaffold is included:
  - [SelectionTranslator.xcodeproj](</Users/yuerenxin/Documents/New project/SelectionTranslator.xcodeproj>)
  - [Xcode/Info.plist](</Users/yuerenxin/Documents/New project/Xcode/Info.plist:1>)
  - [Xcode/Debug.xcconfig](</Users/yuerenxin/Documents/New project/Xcode/Debug.xcconfig:1>)
  - [Xcode/Release.xcconfig](</Users/yuerenxin/Documents/New project/Xcode/Release.xcconfig:1>)
  - [Xcode/SelectionTranslator.entitlements](</Users/yuerenxin/Documents/New project/Xcode/SelectionTranslator.entitlements:1>)
- Full Xcode is not installed in the current environment, so `.xcodeproj` packaging could not be validated here with `xcodebuild`
- Packaging steps are documented in [Xcode/PACKAGING.md](</Users/yuerenxin/Documents/New project/Xcode/PACKAGING.md:1>)
- Real-device debugging notes are documented in [Xcode/TROUBLESHOOTING.md](</Users/yuerenxin/Documents/New project/Xcode/TROUBLESHOOTING.md:1>)
