# CalendarBar

CalendarBar is a small macOS menu-bar app that shows what is happening on your
calendar now and what is coming up next. Your calendar data stays on your Mac.

![CalendarBar app icon](CalendarBar/Assets.xcassets/AppIcon.appiconset/AppIcon-512.png)

## Preview

These mockups use fictional sample events to show the intended light and dark
layouts.

![CalendarBar light and dark mockups](screenshots/CalendarBar-mockups.png)

Open the calendar icon in the menu bar to see your current event, upcoming
events, and the time of each event. CalendarBar has no third-party dependencies
and does not connect to the internet.

## Requirements

- macOS 14 or newer
- Xcode 15 or newer, if building from source

## Install the app

### Homebrew

```bash
brew install --cask treeot/tap/calendarbar
```

Because the app is ad-hoc signed, macOS Gatekeeper still prompts on first launch
— control-click **CalendarBar.app** in Applications, choose **Open**, then
**Open** again.

### Direct download

Download the latest `.dmg` from [Releases](https://github.com/treeot/CalendarBar/releases),
open it, and drag **CalendarBar** into the **Applications** folder.

The releases are ad-hoc signed but are not signed or notarized with a paid
Apple Developer account. macOS may warn that the app cannot be opened or that
Apple cannot verify it. This is expected for these releases.

To open it, control-click **CalendarBar.app** in Applications, choose **Open**,
then choose **Open** again. If macOS still blocks it, go to **System Settings →
Privacy & Security**, scroll down, and click **Open Anyway** for CalendarBar.

After opening the app, choose **Allow Full Access** when macOS asks for calendar
access. CalendarBar then appears in the menu bar and does not show a Dock icon.

## Run from source

1. Open `CalendarBar.xcodeproj` in Xcode.
2. Select the **CalendarBar** scheme and **My Mac** destination.
3. Press **Run** (`⌘R`).
4. Choose **Allow Full Access** when macOS asks for calendar access.

CalendarBar runs only in the menu bar and intentionally has no Dock icon. Click
its calendar icon or title to open the event panel.

The app enables **Launch at Login** on first run. You can turn it off from the
CalendarBar menu. For this feature, use a stable installed copy in
`/Applications`; ad-hoc builds run directly from Xcode are not reliable for
testing Login Items.

If access was previously denied, use CalendarBar's **Open System Settings**
button or go to:

**System Settings → Privacy & Security → Calendars → CalendarBar**

## Calendar access and launch at login

CalendarBar needs macOS Calendar access to show events. You can change this at
any time in **System Settings → Privacy & Security → Calendars → CalendarBar**.

You can enable or disable **Launch at Login** from CalendarBar's settings menu.
For reliable launch-at-login behavior, install the app in `/Applications` from
the DMG instead of running a copy directly from Xcode. Because the app is
unsigned, macOS may require you to approve it in **System Settings → General →
Login Items & Extensions**.

## Build and test

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
