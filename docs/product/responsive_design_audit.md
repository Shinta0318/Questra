# Responsive Design Audit

## Scope

QST-101 reviewed Home, Quest, Mission, Trail, Guild, Arc Chat, Profile, and
onboarding at compact, medium, and expanded widths.

The shared width classes used by Questra are:

- Compact: less than 600 logical pixels.
- Medium: 600 through 1023 logical pixels.
- Expanded: 1024 logical pixels and wider.

## Findings

| Surface | Compact risk | Medium risk | Expanded risk | Follow-up |
| --- | --- | --- | --- | --- |
| Home | Status, section-title, badge, and metric rows can become tight with large text. | A single column is readable but leaves limited room for comparison. | Unbounded content previously stretched cards beyond a useful reading width. | QST-102 caps width; QST-103 should wrap tight rows; QST-110 can introduce richer hierarchy. |
| Quest list | Dashboard metrics and card footer actions can overflow with long labels. | Cards remain a long single-column scan. | Dashboard and Quest cards previously stretched too far. | QST-102 caps width; QST-103 should make metric/action rows adaptive; QST-111 should polish hierarchy. |
| Quest detail/create | Arc header, chips, milestone metadata, and action rows have several fixed `Row` layouts. | The long detail page does not yet use sections side by side. | Form/detail content previously used the entire available width. | QST-102 caps both flows; QST-103 should wrap metadata; QST-111 can optimize detail navigation. |
| Mission | Signal tiles and completion actions can be compressed by long Japanese text. | The list remains intentionally linear. | Mission cards previously expanded beyond comfortable reading width. | QST-102 caps width; QST-103 should verify action rows at text scale. |
| Trail | Timeline metadata, attachment actions, and sync banners contain tight rows. Bottom sheets need keyboard checks. | Timeline remains readable but underuses horizontal room. | Trail cards and timeline previously stretched across the viewport. | QST-102 caps width; QST-103 should fix row wrapping and sheet insets; QST-112 should polish timeline density. |
| Guild | Match tiles, review badges, and feed actions can compete for width. | Feed remains a single column. | Long feed text previously produced very wide lines. | QST-102 caps width; QST-103 should wrap actions; QST-113 should refine feed scanning. |
| Arc Chat | Header, quick actions, and input controls are vulnerable to narrow width and large text. | Conversation width is readable; input remains full-width. | Conversation bubbles benefit from a centered reading column, while header/input still span the surface. | QST-102 centers history; QST-103 should harden input/header; QST-105 should expose history scrollability. |
| Profile | Identity, rank, and stat rows can become tight with long account values. | A capped column is appropriate for account settings. | Unbounded account cards previously became too wide. | QST-102 applies a 720px cap; QST-103 should wrap stat rows; QST-115 should test semantics and text scale. |
| Onboarding | Keyboard, text scale, and long choice labels can reduce usable height. | A focused form column is appropriate. | The form previously expanded unnecessarily. | QST-102 applies a 640px cap; QST-103 should verify keyboard and landscape behavior. |

## Cross-Cutting Conclusions

1. Most major screens already use `SafeArea` and a vertical scroll container.
2. Width behavior was ad hoc and had no shared compact, medium, or expanded
   definition.
3. Fixed `Row` layouts are the highest compact-width and large-text risk.
4. Bottom sheets and Arc Chat input need explicit keyboard-overlap validation.
5. Expanded layouts should remain readable before optional multi-column
   enhancements are introduced.

## Resolution

QST-102 introduces shared breakpoint and content-width rules and applies them
to all audited surfaces. Remaining overflow and input-inset risks move to
QST-103.
