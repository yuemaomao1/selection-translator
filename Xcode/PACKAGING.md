# Packaging Guide

This document describes how to run, sign, and archive `SelectionTranslator` with full Xcode.

## 1. Open The Project

Open:

- [SelectionTranslator.xcodeproj](</Users/yuerenxin/Documents/New project/SelectionTranslator.xcodeproj>)

Confirm the target uses:

- `Xcode/Info.plist`
- `Xcode/SelectionTranslator.entitlements`
- `Xcode/Debug.xcconfig`
- `Xcode/Release.xcconfig`

## 2. Set Bundle And Team

In Xcode target settings:

1. Set `Signing & Capabilities` -> Team
2. Replace `PRODUCT_BUNDLE_IDENTIFIER` from `com.example.SelectionTranslator` to your real identifier
3. Keep automatic signing on unless you have a manual signing workflow already

## 3. Build A Real App Bundle

Use Xcode's normal `Run` flow first, not `swift run`.

Why:

- Accessibility permissions are more realistic against an app bundle
- Launch-at-login uses `SMAppService.mainApp`, which is intended for signed app bundles
- You can validate menu bar behavior, login item registration, and permissions in a production-like shape

## 4. Grant Permissions

After first launch:

1. Open `System Settings` -> `Privacy & Security` -> `Accessibility`
2. Enable the built app
3. Relaunch if needed

If login item approval is requested:

1. Open `System Settings` -> `General` -> `Login Items`
2. Approve the app if macOS shows a pending item

## 5. Recommended Manual QA

Check these scenarios with the built `.app`:

1. Select English text in TextEdit and trigger translation
2. Select Chinese text in Notes and trigger translation
3. Confirm no selection means the shortcut passes through
4. Confirm selected text means the shortcut is intercepted
5. Confirm panel placement prefers right, then other sides when space is limited
6. Confirm panel never covers the selected text in normal cases
7. Confirm clipboard fallback works in at least one app that does not expose AX selected text directly
8. Confirm pinning prevents outside-click close and allows dragging
9. Confirm launch-at-login toggle reflects the real app state

## 6. Archive

When ready:

1. Choose `Any Mac` or your target Mac destination
2. `Product` -> `Archive`
3. Validate signing in the Organizer
4. Export as a Developer ID app or the distribution style you need

## 7. Notes

- System translation requires macOS 15+
- The current entitlement file is intentionally minimal
- If you later add sandboxing, reevaluate Accessibility, event tap, clipboard fallback, and login-item behavior carefully
- If validation fails on a real machine, use [TROUBLESHOOTING.md](</Users/yuerenxin/Documents/New project/Xcode/TROUBLESHOOTING.md:1>)
