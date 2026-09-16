# CalendarBar

CalendarBar is a lightweight, menu-bar-only macOS app built with SwiftUI and EventKit. It shows the current calendar event, every remaining timed event today, and a live minute countdown to the next event.

![CalendarBar app icon](CalendarBar/Assets.xcassets/AppIcon.appiconset/AppIcon-512.png)

## Preview

These mockups use fictional sample events to show the intended light and dark
layouts.

![CalendarBar light and dark mockups](screenshots/CalendarBar-mockups.png)

It has no third-party dependencies or networking. Open the menu-bar item to
see current and upcoming events.

## Requirements

- macOS 14 or newer
- Xcode 15 or newer
- No third-party dependencies
- No paid Apple Developer account for local use

## Run it

1. Open `CalendarBar.xcodeproj` in Xcode.
2. Select the **CalendarBar** scheme and **My Mac** destination.
3. Press **Run** (`⌘R`).
4. Choose **Allow Full Access** when macOS asks for calendar access.

CalendarBar runs only in the menu bar and intentionally has no Dock icon. Click its calendar icon/title to open the event panel.

The app enables **Launch at Login** on first run. You can turn it off from the
CalendarBar menu. For this feature, use a stable installed copy in
`/Applications`; ad-hoc builds run directly from Xcode are not reliable for
testing Login Items.

If access was previously denied, use CalendarBar's **Open System Settings** button or go to:

**System Settings → Privacy & Security → Calendars → CalendarBar**

## Permissions

CalendarBar uses the macOS Calendar permission and runs as a menu-bar-only app.
If access was previously denied, open **System Settings → Privacy & Security →
Calendars → CalendarBar**.

## Command-line verification

Build without signing:

```bash
xcodebuild build \
  -project CalendarBar.xcodeproj \
  -scheme CalendarBar \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO
```

Run the unit tests:

```bash
xcodebuild test \
  -project CalendarBar.xcodeproj \
  -scheme CalendarBar \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO
```

GitHub Actions runs the build and tests for pushes and pull requests to `main`.

## Installation and releases

To create a release, push a tag using the form `vMAJOR.MINOR.PATCH`:

```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions creates an unsigned DMG with an Applications shortcut. For a
public release, sign and notarize the app with an Apple Developer account.

## License

CalendarBar is available under the [MIT License](LICENSE).

## Behavior notes

- CalendarBar refreshes every 60 seconds and whenever EventKit reports a calendar-store change.
- It reads timed events from today and excludes all-day events.
- It shows the active event under **Now** and every future event today under **Upcoming events**.
- Each event has actions to open Apple Calendar or copy its title.
- The menu-bar display can be **Full**, **Compact** (the default), or **Icon Only**. Hold `⌘` and drag the menu-bar item to position it among your other status items.
- Calendar data stays local; the app contains no networking code.
