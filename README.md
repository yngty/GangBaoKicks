# GangBaoKicks

GangBaoKicks is a native SwiftUI iPhone and Apple Watch app for calm fetal movement tracking. It focuses on quick manual counting, gentle feedback, bilingual copy, themed visuals, and local-first history.

## Features

- iPhone and Apple Watch fetal movement counting.
- Manual `+1` recording with duplicate filtering.
- Configurable observation duration, defaulting to 1 hour.
- Configurable duplicate interval, defaulting to 2 minutes.
- Raw taps, effective kicks, and duplicate taps are preserved in session data.
- Manual session ending, notes, and simple tags.
- Local session history stored with `UserDefaults`.
- WatchConnectivity sync for live state and completed sessions.
- Daily reminder scheduling.
- CSV export from iPhone through the system share sheet.
- English and Simplified Chinese localization.
- Switchable visual themes: mint, peach, sky, and lavender.

## Project Structure

```text
Apps/iOS/      iPhone app entry point, main UI, settings, history, export
Apps/Watch/    Apple Watch app entry point and watch counting UI
Shared/        Models, store, sync, reminders, formatting, themes, localization
project.yml    XcodeGen project definition
```

## Requirements

- macOS with Xcode installed.
- XcodeGen 2.45 or newer.
- iOS 17.0 or newer.
- watchOS 10.0 or newer.

## Generate The Xcode Project

`project.yml` is the source of truth for targets, schemes, bundle identifiers, and generated plist settings.

```sh
cd /Users/howie/workspace/project/GangBaoKicks
xcodegen generate
open GangBaoKicks.xcodeproj
```

Before running on a physical device, select an Apple development team in Xcode.

## Build From Terminal

```sh
cd /Users/howie/workspace/project/GangBaoKicks
xcodebuild -project GangBaoKicks.xcodeproj -scheme GangBaoKicks -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/DerivedData build
xcodebuild -project GangBaoKicks.xcodeproj -scheme 'GangBaoKicks Watch App' -destination 'generic/platform=watchOS Simulator' -derivedDataPath .build/DerivedData build
```

## Bundle Identifiers

- iPhone app: `com.gangbao.GangBaoKicks`
- Watch app: `com.gangbao.GangBaoKicks.watchkitapp`
