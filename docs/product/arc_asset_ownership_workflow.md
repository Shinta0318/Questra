# Arc Asset Ownership and Candidate Package Workflow

Status: QST-369 implemented; chain-of-title approval pending.

QST-378 adds a fail-closed intake command for hash-bound Product/Legal records:

```bash
dart run tools/qst/intake_arc_asset_chain_of_title.dart --record=<review-record.json>
```

The command validates the live asset hash, approved commercial usage, both
review references, and rejects sensitive fields before writing a normalized
record under `docs/qst/arc_asset_chain_of_title/`.

## Package Boundary

Only assets registered under Flutter's `assets:` section may enter candidate
artifacts. The current runtime package contains seven Arc expression PNGs.
Files under `apps/mobile/assets/mockups/` are repository design references and
must not be registered, loaded at runtime, or shipped in Web/Android artifacts.

Generate and verify the candidate package inventory:

```bash
dart run tools/qst/generate_candidate_asset_package.dart
dart run tools/qst/verify_candidate_asset_package.dart
```

## Ownership Review

Each runtime asset requires evidence bound to its SHA-256:

1. Original source file or generation job identifier.
2. Creator or generation provider and account owner.
3. Creation/import date and prompt or commission brief when applicable.
4. Terms/license version that permits commercial app distribution.
5. Any model, reference-image, trademark, or third-party restrictions.
6. Product Owner approval for the intended use.
7. Legal Reviewer approval for the intended regions and channels.

Do not store account credentials, signatures, private prompts, or unrelated
personal data in the repository. Store a reference to the controlled evidence
location and the reviewer decision instead.

## Hash Change Rule

Any byte change creates a new asset identity. Existing Product/Legal approval is
invalidated, `release_allowed` returns to `false`, provenance evidence must be
reviewed again, and the candidate package manifest must be regenerated. A file
name match is not approval.

## Candidate Gate

The normal verifier confirms package hygiene without asserting ownership. Public
release additionally requires:

```bash
dart run tools/qst/verify_arc_asset_provenance.dart --require-release
dart run tools/qst/verify_candidate_asset_package.dart --require-release
```

Both commands must pass on a clean candidate SHA. Repository presence, a visual
mock, or prior use in a local build does not prove chain of title.
