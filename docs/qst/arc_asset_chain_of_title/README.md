# Arc Chain-of-Title Intake Records

This directory accepts one approved JSON review record per immutable asset
SHA-256. Use `tools/qst/intake_arc_asset_chain_of_title.dart`; do not add raw
signatures, credentials, private prompts, or personal reviewer information.

Required record fields:

- `schemaVersion`: `1`
- `assetPath` and `assetSha256`
- `sourceKind`, `sourceEvidenceRef`, `creatorController`, `creationContext`
- `termsName`, `termsVersion`, `termsReference`
- `commercialDistributionAllowed`: `true`
- `productReviewRef`, `productDecision`: `approved`
- `legalReviewRef`, `legalDecision`: `approved`
- `reviewedUsage`: non-empty list of approved channels/regions
- `reviewedAtUtc`: ISO-8601 timestamp

The checked-in asset bytes must match the reviewed hash. A changed asset needs
a new record and invalidates the prior release decision.
