# Release Assets and Legal Copy Readiness

## Purpose

Track the beta-facing assets and legal copy required before Questra can move
from internal beta preparation toward public release review.

## Ownership

| Area | Owner | Reviewer | Status | Artifact |
| --- | --- | --- | --- | --- |
| App icon | Design Owner | Release Manager | Draft needed | Existing platform placeholders tracked below |
| Splash assets | Design Owner | Release Manager | Draft needed | Existing platform placeholders tracked below |
| Terms of Service | Product Owner | Legal Reviewer | Draft created | `docs/legal/terms_of_service_draft.md` |
| Privacy Policy | Product Owner | Legal Reviewer | Draft created | `docs/legal/privacy_policy_draft.md` |
| Store listing copy | Product Owner | Release Manager | Draft created | `docs/product/store_listing_draft.md` |

## Asset Inventory

| Platform | Asset | Current State | Beta Requirement |
| --- | --- | --- | --- |
| Android | `android/app/src/main/res/mipmap-*/ic_launcher.png` | Flutter default icon present | Replace with Questra icon set before public release |
| Android | `android/app/src/main/res/drawable*/launch_background.xml` | Flutter default splash background present | Add Questra splash color/image treatment |
| iOS | `ios/Runner/Assets.xcassets/AppIcon.appiconset` | Flutter default icon set present | Replace with Questra icon set before public release |
| iOS | `ios/Runner/Assets.xcassets/LaunchImage.imageset` | Flutter default launch images present | Replace or remove in favor of Questra launch treatment |

## Legal Copy Checklist

- Terms must describe Questra as a Quest, Mission, Trail, Guild, and Arc
  experience.
- Terms must not describe Arc as an AI Assistant.
- Privacy copy must cover account data, Quest/Mission/Trail content, Arc Memory,
  media uploads, Guild activity, analytics events, and reports.
- Privacy copy must explain deletion/export request channels before public
  release.
- Legal drafts require human legal review before external distribution.

## Store Listing Checklist

- App name: Questra.
- Subtitle/tagline should focus on guided quests and personal progress.
- Description should mention Quest, Mission, Trail, Guild, and Arc in product
  language.
- Do not use `Story` as a product concept.
- Do not call Arc an AI Assistant.
- Screenshots remain pending until beta UI is locked.

## Beta Readiness

Internal beta can proceed with draft legal/store artifacts and tracked asset
owners. Public release remains blocked until final app icons, splash assets, and
human-reviewed legal copy are approved.
