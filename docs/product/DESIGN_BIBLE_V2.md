# Questra Design Bible V2

Status: Beta baseline. The Master Spec is higher authority.

Questra is a calm premium journey companion: deep navy space, cosmic blue depth, restrained gold for milestones, and Arc as a warm navigator. It is not a game dashboard, generic task app, or chat-bot shell.

| Screen | Primary action | Required state |
| --- | --- | --- |
| Home | Continue today's Task | Arc, Task with parent Mission, active Quest above fold |
| Arc | Consult or shape a Quest | expression, short response, input above keyboard |
| Quest | See and refine a route | theme card, AI evaluation, linked Missions |
| Mission | Confirm an intermediate outcome | success condition, Task progress, support |
| Task | Take one concrete action | parent Mission, status, primary action |
| Trail | Record a moment | media, reflection, retry/error |
| Guild | Discover or safely participate | approved content and moderation state |
| Auth | Continue securely | login, recovery, validation |
| Profile | Review identity and preferences | privacy and experience settings |

## Responsive and accessibility rules

- Compact: 320px and up. Medium: 600px and up. Expanded: 840px and up.
- Support large text without clipping controls or hiding primary actions.
- Maintain semantic labels, 44px touch targets, visible focus states, and suitable contrast.
- Use short Japanese sentences. Labels name the action; explanatory copy appears only where ambiguity remains.

## Form composition rules

- Labels live above fields in the order `Label -> Helper -> Input -> Counter / Validation`; floating labels are not used.
- Short inputs are 56-64px, medium inputs 72-88px, long inputs 110-160px, and primary actions at least 48px high. Flutter uses `AppFieldSizes` as the source of truth.
- Reflective inputs such as motivation and success evidence use one column on mobile, tablet, and desktop. They are never placed side by side.
- Quest creation content is centered and capped at 780px. Screen padding is 16-24px on compact layouts and at least 24px on expanded layouts.
- User decisions, Arc suggestions, and AI-derived evaluations must be visually distinct. Difficulty and Quest DNA theme are read-only analysis during initial creation.
- Desired completion timing is a user-owned `YYYY / MM` value. Arc may compare it with an estimate, but never silently replaces it.
- Multiline fields keep Japanese IME composition intact. Enter inserts a line break unless the field is an explicit send control.
- Character counters remain below the editable content and must not cover typed text.

## Domain hierarchy rules

- Quest is the desired outcome and owns the route.
- Mission is a verifiable intermediate outcome, never a generic task row.
- Task is the smallest concrete action and always displays its parent Mission.
- Trail records what happened after action; it is not used as a Task substitute.
- Required Task completion may show a Mission as ready for confirmation, but the
  Mission completes only after explicit success or output confirmation.

## Golden change rule

A visual baseline change requires its screen, viewport, intentional reason, screenshot reference, and reviewer record in the QST report.
# Quest Intent Confirmation

- Quest候補を表示すること自体を目的にしない。意図が明確なら候補選択を省略する。
- 入力文字列へ「小さく試す」「習慣にする」などを付加する固定変換を禁止する。
- Arcの確認質問は、航路・安全性・成功条件が変わる場合に限り最大3問とする。
- 複数案は達成状態が実質的に異なる場合だけ2〜3案を表示し、単なる言い換えを並べない。
- 画面順序は「願いの入力 → ArcがまとめたQuest → ユーザー確認 → Mission Planning」とする。
- Quest Typeは内部属性として扱い、ユーザーへ選択を強制しない。
