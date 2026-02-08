# TrainingApp (iOS)

Offline-first lifting + running training logger built with SwiftUI.

## Open

1. Open `/Users/alexbalagurakpersonal/Documents/dev/training-app/TrainingApp.xcodeproj` in Xcode.
2. Select the `TrainingApp` scheme.
3. Run on iPhone simulator or device.

## What is implemented

- Account creation flow (local, on-device).
- Home dashboard with fresh session start, quick template start, and continue active session.
- Workout session editor:
  - Rename workout.
  - Add exercises from library or create custom exercises.
  - Add/edit/delete sets (swipe left to delete).
  - Reps/weight are prefilled from last completed performance of that exercise.
  - Tap set number to mark set type (`Warm-Up`, `Working`, `Failure`, `Drop Set`).
  - Workout notes + exercise notes.
  - Large `HH:MM:SS` session timer + session date.
  - Add/edit run inside the lifting session.
- Running support:
  - Manual treadmill entry (distance + duration).
  - GPS run tracking via CoreLocation (distance, duration, route points).
- Template system:
  - Create/edit/delete templates.
  - Create folders and assign templates into folders.
  - Save active session as a template.
- History:
  - Session history list.
  - Calendar mode with day filtering.
  - Swipe-left delete for workout sessions.
- Progress:
  - KPI tiles (sessions, templates, total volume, run distance).
  - Strength progress chart by exercise over time.
  - Running distance chart over sessions.
- Appearance:
  - Default dark mode.
  - Switch to light/system from Settings.
  - Material/glass styling with gradient background.

## Storage model

- Offline-first JSON persistence to Application Support.
- State includes account, exercise library, folders, templates, sessions, active session draft, and last-set memory cache.

## Garmin compatibility note

- Garmin sync is not yet integrated.
- Run/session data models were structured to support future sync adapters.

## Build check completed

Validated with:

```bash
xcodebuild -project TrainingApp.xcodeproj -scheme TrainingApp -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/TrainingAppDerived CODE_SIGNING_ALLOWED=NO build
```
