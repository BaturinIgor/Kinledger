# Kinledger

A care log for the one person who looks after an aging parent. Log hours, expenses and visits in seconds; once a month, send siblings a private report they open in the browser, with no app and no account.

iOS first, native SwiftUI (iOS 17+). Android comes later as a separate app.

## Docs

- [Roadmap](docs/roadmap.md)
- [Data safety](docs/data-safety.md)
- [Design tokens](docs/design.md)

## Run

Needs a Mac with Xcode 16 or newer and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
open Kinledger.xcodeproj
```

Run the app with Cmd+R and the tests with Cmd+U. The `.xcodeproj` is generated from `project.yml` and is not committed.
