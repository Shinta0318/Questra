# Responsive QA Automation

QST-118 adds a repeatable viewport matrix for beta responsive checks.

## Viewports

| Class | Size | Purpose |
| --- | --- | --- |
| Compact | 390 x 844 | Typical phone portrait layout. |
| Medium | 800 x 900 | Tablet / narrow desktop behavior with navigation rail. |
| Expanded | 1280 x 900 | Desktop web and wide tablet behavior. |

## Covered Surfaces

- Home
- Quest
- Quest Detail
- Mission
- Trail
- Guild
- Arc
- Profile
- Onboarding

## Commands

Run from `apps/mobile`:

```powershell
flutter test test/responsive_viewport_matrix_test.dart
flutter test test/responsive_screen_smoke_test.dart
flutter test test/bottom_navigation_v2_test.dart
```

For a full beta regression pass:

```powershell
dart analyze lib test
flutter test
```

## Pass Criteria

- No Flutter layout exceptions at compact, medium, or expanded viewport sizes.
- Major surfaces render inside a `SafeArea` or equivalent app shell.
- Scrollable surfaces remain usable without horizontal overflow.
- Navigation form changes by viewport without losing access to Home, Quest,
  Trail, Guild, Arc, and Profile.
- Large-text compact checks remain green in `responsive_screen_smoke_test.dart`.

## Stop Conditions

- Any `RenderFlex overflowed` exception.
- Any route or surface fails to build.
- Arc input or bottom sheet controls overlap keyboard checks.
- Navigation becomes inaccessible at any viewport class.
