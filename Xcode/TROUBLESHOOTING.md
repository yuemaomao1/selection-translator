# Troubleshooting

This guide focuses on the most common problems you may hit while validating `SelectionTranslator` on a real Mac.

## 1. Shortcut Does Nothing

Check in this order:

1. Confirm the app is actually running in the menu bar
2. Open `设置…` and verify the current recorded shortcut
3. Try a simpler shortcut such as `Option+T`
4. Confirm the foreground app supports normal text selection
5. Confirm Accessibility permission is enabled for the built app bundle, not just Terminal or Xcode

If you are testing with `swift run`:

- Permissions may be attached to Terminal rather than the future app bundle
- Launch-at-login behavior is not representative

## 2. Accessibility Permission Was Granted But It Still Fails

Try:

1. Disable and re-enable the app in `System Settings` -> `Privacy & Security` -> `Accessibility`
2. Quit and relaunch the app
3. Quit and relaunch the target foreground app
4. Prefer testing with a built `.app` from Xcode rather than `swift run`

Common cause:

- The permission was granted to a different binary identity than the one currently running

## 3. Shortcut Types Into The Foreground App Instead Of Triggering

Likely reasons:

- There is no actual selection, so the app correctly passes the shortcut through
- The selected control does not expose selection info through Accessibility
- The recorded shortcut is not what you think it is

How to confirm:

1. Select text in TextEdit
2. Trigger translation
3. If it works there but not elsewhere, the issue is app-specific AX support rather than the event tap itself

## 4. Panel Appears But No Translation Shows

Check:

1. macOS version is 15 or newer
2. The selected text is mostly English or Chinese
3. The system Translation framework is available on this machine

If the panel shows a failure message:

- Read it literally first; the app already distinguishes permission, unsupported app, and translation failures

## 5. Selected Text Cannot Be Read

Symptoms:

- You see the unsupported-app message
- The shortcut is intercepted but no translation content appears

What to try:

1. Turn on clipboard fallback in `设置…`
2. Re-test in the target app
3. If still failing, test the same flow in TextEdit or Notes

Interpretation:

- Works in TextEdit but not in the target app: the target app likely does not expose AX selection reliably
- Fails everywhere: revisit Accessibility permission first

## 6. Panel Position Falls Back Near The Mouse

This usually means:

- Selected text bounds were not available
- The app exposed selected text or range, but not usable geometry

This is expected in some apps. It is not always a bug in placement logic.

## 7. Clipboard Fallback Does Not Work

Possible causes:

- The target app does not honor synthetic `Cmd+C`
- The selection is not actually copyable
- Another app or automation is racing the clipboard

Try:

1. Manually press `Cmd+C` in the target app
2. Confirm copied text really lands in the clipboard
3. Re-test with clipboard fallback enabled

## 8. Launch At Login Does Not Stay Enabled

Most common reason:

- You are not running a signed `.app` bundle

Checklist:

1. Run from Xcode as a real app target
2. Set Team and Bundle ID
3. Open `System Settings` -> `General` -> `Login Items`
4. Check whether macOS is waiting for approval

## 9. The Recorded Shortcut Seems Wrong

Notes:

- The recorder captures displayable key combinations
- Press `Esc` to cancel recording
- Use the reset button to go back to the default shortcut

Recommended testing shortcuts:

- `Option+T`
- `Control+Space`
- `Command+Shift+2`

Avoid shortcuts already heavily used by macOS or your IME during testing.

## 10. What To Test First When Unsure

Use this baseline:

1. Build and run the `.app` from Xcode
2. Grant Accessibility permission
3. Open TextEdit
4. Select English text
5. Trigger translation with `Option+T`
6. Confirm the panel appears, translates, copies, toggles original/translation, and auto-dismisses

If that baseline works, most remaining issues are app-specific compatibility issues rather than core app failures.
