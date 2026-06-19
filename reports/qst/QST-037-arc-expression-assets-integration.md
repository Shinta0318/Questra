# QST-037 Arc Expression Assets Integration

## Status

Done

## Summary

Integrated the prepared Arc expression PNGs as official Flutter assets and
connected the existing Arc UI to use the PNG expression set through centralized
asset paths.

## Changed Files

- `apps/mobile/pubspec.yaml`
- `apps/mobile/assets/characters/arc/arc_normal.png`
- `apps/mobile/assets/characters/arc/arc_happy.png`
- `apps/mobile/assets/characters/arc/arc_cheering.png`
- `apps/mobile/assets/characters/arc/arc_serious.png`
- `apps/mobile/assets/characters/arc/arc_worried.png`
- `apps/mobile/assets/characters/arc/arc_sad.png`
- `apps/mobile/assets/characters/arc/arc_celebration.png`
- `apps/mobile/lib/widgets/arc/arc_asset_paths.dart`
- `apps/mobile/lib/widgets/arc/arc_widget.dart`
- `apps/mobile/test/arc_asset_paths_test.dart`
- `reports/qst/QST-037-arc-expression-assets-integration.md`

## Asset Placement

Copied 7 Arc expression PNGs from:

`C:\Users\shint\Downloads\arc_expression_assets\assets\characters\arc`

to:

`apps/mobile/assets/characters/arc/`

The Flutter asset directory is registered in `apps/mobile/pubspec.yaml` as:

```yaml
flutter:
  assets:
    - assets/characters/arc/
```

## Implementation Notes

- Added `ArcAssetPaths` to centralize all Arc expression asset paths.
- Mapped existing `ArcEmotion` values to the new expression PNGs.
- Updated `ArcWidget` to render the PNG asset for the selected Arc emotion.
- Kept the previous generated Arc visual as a fallback if an asset fails to
  load.
- Added tests to verify expression path mapping and `arc_normal.png` rendering
  through `ArcWidget`.

## Verification

- Passed: `flutter pub get`
- Passed: `dart format apps/mobile/test/arc_asset_paths_test.dart apps/mobile/lib/widgets/arc/arc_asset_paths.dart apps/mobile/lib/widgets/arc/arc_widget.dart`
- Passed: `flutter analyze`
- Passed: `flutter test -r expanded`
- Passed: `dart run tools\qst\verify_rls_readiness.dart`
- Passed: app source naming/framing search for this change

## Next QST Candidate

- Arc Expression Engine
