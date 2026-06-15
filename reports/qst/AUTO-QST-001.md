# Questra Standard QST Report v1.0

## QST ID

AUTO-QST-001

## Title

Trail terminology migration

## Changed files

- apps/mobile/lib/core/router/app_router.dart
- apps/mobile/lib/core/router/app_routes.dart
- apps/mobile/lib/core/router/app_shell.dart
- apps/mobile/lib/features/home/home_screen.dart
- apps/mobile/lib/features/trail/trail_screen.dart
- reports/qst/AUTO-QST-001.md

## Implementation summary

- Selected the next implementation task from the available Questra backlog signals: remove legacy Story wording and align the app with Trail terminology.
- Renamed the old Story feature screen to `TrailScreen`.
- Moved the screen from `features/story/story_screen.dart` to `features/trail/trail_screen.dart`.
- Updated routing from `/story` to `/trail`.
- Updated bottom navigation label from Story to Trail.
- Updated Home copy from Recent Story to Recent Trail.
- Removed the empty legacy `features/story` directory.

## Test results

- `dart format lib`
- `flutter analyze`
- `flutter test`
- Source search for `Story|story|Stories|stories`: no remaining app source matches.

## Known issues

- The requested Project Planner, Auto Backlog Generator, and Prompt Generator are not present in this target repository yet, so the selected QST was applied from the same Questra rule set manually against the target app state.
- QST management tooling should be migrated into `C:\Users\shint\StudioProjects\Questra` in a future QST so selection can be fully automated inside this repository.

## Next QST candidates

- Migrate QST Planner tooling into this repository.
- Add formal Trail data model and posting flow.
- Add Arc Chat MVP surface.

## Master Spec compliance notes

- Legacy Story terminology was removed from app source.
- Record/Post concepts are now represented as Trail in user-facing navigation and screen copy.
- Arc remains represented as Questra's guide.
- The change is scoped to terminology and routing without unrelated refactors.
