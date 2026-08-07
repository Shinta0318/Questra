# QST-178〜187 Quest Planning and Safety Epic Plan

## Status

Backlog planned. Implementation has not started.

## Goal

QuestとMissionの意味・親子関係を修復し、Arcによる願いの言語化、安全判定、AI難易度・期間推定、期限再提案、Mission支援、チャット操作を一つのBeta品質エピックとして進める。

## Planned Sequence

1. QST-178 Quest and Mission Domain Contract Repair
2. QST-179 Quest Intent Safety Moderation Gate
3. QST-180 Arc Wish Articulation and Reality Framing
4. QST-181 Abuse Signals and Account Restriction Readiness
5. QST-182 AI Quest and Mission Effort Estimation
6. QST-183 Quest Target Month and Feasibility Replanning
7. QST-184 AI Mission Research and Support Hub V1
8. QST-185 Transparent Enterprise Quest Support Preview
9. QST-186 Arc Chat Keyboard Composer Contract
10. QST-187 Quest Planning and Safety Integration Review

## Product Decisions

- Questは達成したい結果、MissionはQuestを進める観測可能な行動として扱う。
- Missionは必ず所有者が同じ一つのQuestへ紐づく。
- 難易度と期間はAI推定とするが、確信度と理由を示し、断定値として扱わない。
- 期限は日付を強制せず `yyyy/MM` の目標月として確認する。
- 間に合わない可能性が高い場合も期限を勝手に変更せず、再提案を本人が選ぶ。
- 野心的なQuestを単に「不可能」として拒否しない。文字どおり不可能な結果は、意味を保った実現可能な形へ言い換える。
- 重大な危害につながる要望はQuest生成前に拒否する。センシティブな単語だけでは拒否しない。
- 誤判定を考慮し、AI判定だけによる自動永久BANは実装しない。重大度、反復性、レビュー、異議申立てを分離する。
- Mission参考情報はサーバー側検索で取得し、現在情報の主張には引用、出典、取得日、検証状態を必須とする。存在しないURLを生成しない。
- Mission支援画面は `Arcが調べた情報` と `企業からの支援` を視覚・データ・分析イベントのすべてで分離する。
- 企業提案は企業情報、役割、支援内容、費用、条件、対象地域、年齢条件、有効期限、広告関係、申込先、審査状態を持つ。
- 企業支援は機能フラグと事前審査配下の透明な支援枠とし、Arcを営業担当にしない。
- Web・デスクトップではEnter送信、Alt+Enter改行とし、日本語IME確定は送信扱いにしない。

## Master Spec Alignment

- Arcは常にユーザーの味方であり、安全上の拒否でも人格攻撃や説教をしない。
- 企業はQuestを押し付けず、既存Missionの実行可能性を高める支援だけを行う。
- 挑戦データ、チャット本文、違反シグナルは目的を分離し、必要最小限だけ保持する。
- QuestraをToDoまたは単純なチャットへ縮退させず、Quest、Mission、Trailの旅路を中心にする。

## First Implementation Target

QST-178から開始する。最初にデータ契約とUI上の親子関係を安定させ、その後のAI推定、期限配分、支援情報が誤ったMissionへ紐づかない状態を作る。

## Validation

- `BACKLOG.yaml` parses as valid YAML.
- 135 QST entries are unique.
- QST-178〜187 contain title, goal, scope, priority, dependencies, likely files, and acceptance criteria.
- Every declared dependency resolves to an existing QST.
