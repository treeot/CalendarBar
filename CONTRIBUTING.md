# Contributing to CalendarBar

Thanks for helping improve CalendarBar.

## Development setup

1. Install macOS 14 or newer and Xcode 15 or newer.
2. Clone the repository and open `CalendarBar.xcodeproj`.
3. Select the `CalendarBar` scheme and the `My Mac` destination.
4. Run the app or the test suite from Xcode.

CalendarBar uses only Apple frameworks and stores calendar data locally. You
may need to grant Calendar access when running the app.

## Before opening a pull request

- Keep changes focused and explain user-visible behavior in the PR description.
- Add or update unit tests for changes to calendar and timeline behavior.
- Run the commands in the README's **Command-line verification** section.
- Do not commit Xcode user state, build output, credentials, or personal data.

## Pull requests

Please include a concise summary, testing performed, and screenshots or a
short recording for visible UI changes. Maintainers may ask for changes to
preserve macOS accessibility, privacy, and menu-bar conventions.
