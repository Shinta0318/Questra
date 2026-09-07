# Accessibility Release Gate

Status: QST-350 local baseline

## Purpose

Questra must remain usable on compact screens, large text, keyboard, Japanese
IME, and screen-reader flows before Beta distribution. Accessibility evidence is
not a decorative QA step; it is a release gate tied to the candidate SHA.

## Local Static Gate

Run:

```bash
dart run tools/qst/verify_accessibility_release_gate.dart
```

The local gate checks:

- Master Spec and Design Bible include the accessibility requirements.
- Japanese IME keyboard behavior has an automated test.
- Bottom navigation has semantic destination coverage.
- Responsive viewport tests include compact width coverage.
- `FittedBox`, `BoxFit.scaleDown`, and `AutoSizeText` are not used in app UI to
  cancel the user's requested text size.

## Physical Evidence Gate

Before external Beta, run:

```bash
dart run tools/qst/verify_accessibility_release_gate.dart --require-physical-evidence
```

Evidence must first be recorded from a clean candidate SHA with
`tools/qst/record_physical_accessibility_evidence.dart`. The recorder requires
six privacy-reviewed artifacts under `artifacts/qst376/`, stores their SHA-256,
and verifies the selected device through ADB before rejecting emulator-only or
stale-SHA evidence. Device identifiers are never written to the evidence file.

Example recording command:

```bash
dart run tools/qst/record_physical_accessibility_evidence.dart \
  --candidate-sha=<sha> --tester-role=release-reviewer \
  --device-id=<adb-device-id> --privacy-reviewed=true \
  --physical_android=artifacts/qst376/physical_android.mp4 \
  --talkback=artifacts/qst376/talkback.mp4 \
  --japanese_ime=artifacts/qst376/japanese_ime.mp4 \
  --large_text_200=artifacts/qst376/large_text_200.mp4 \
  --compact_layout=artifacts/qst376/compact_layout.mp4 \
  --reduced_motion_and_haptics=artifacts/qst376/reduced_motion_and_haptics.mp4
```

The physical gate requires `docs/qst/PHYSICAL_ACCESSIBILITY_EVIDENCE.yaml` to
include candidate-bound evidence for:

- `candidate_sha`
- `physical_android`
- `talkback`
- `japanese_ime`
- `large_text_200`
- `compact_layout`
- `reduced_motion_and_haptics`

## Manual Evidence Checklist

The release owner must capture:

- Compact 320px-equivalent journey through Home -> Arc -> Quest -> Task -> Trail.
- 200% text scale with no clipped primary CTA.
- Japanese IME composition in Arc Chat and Quest creation fields.
- TalkBack reading order for Home, Arc, Quest detail, Task action, and Trail.
- Keyboard focus restore after loading, retry, dialogs, and route transitions.
- Reduced motion and haptics opt-out confirmation.

## Rollback

Accessibility fixes are retained by default. If a shell rollout introduces a
navigation or focus regression, disable the shell flag and keep token-level
contrast, tap-target, and IME fixes.
