# Questra Screen State Matrix V1

## Purpose

主要画面の目的、最重要操作、状態、証跡を一つの契約へ揃える。画面の存在や
happy pathだけでBeta完成を判断せず、空・読込・保存・失敗・offlineを明示する。

機械可読な正本は`docs/qst/PRIMARY_SCREEN_STATE_MATRIX.yaml`とする。

## Product rules

- Homeは次の一歩を一つに絞る。
- Arcは会話だけでなく、同意を得てQuestと航路へつなぐ。
- QuestはMissionとTaskの親であり、単なるタスクリストにしない。
- TrailはQuestとMissionに紐づく旅の記録である。
- Profileは設定と権利管理への安定した入口である。
- Onboardingは3画面を基本とし、Back、Skip、途中再開を保証する。
- ErrorとOfflineは入力を失わず、再試行または安全な手動経路を示す。
- AI fallbackで固定Missionを捏造しない。

## Evidence levels

1. `code_only`: routeまたはWidgetだけ存在する。
2. `widget_verified`: deterministic providerによるWidget Testがある。
3. `golden_verified`: locale、font、viewport、motion条件を固定したGoldenがある。
4. `physical_verified`: candidate SHAを固定したAndroid／Web操作証跡がある。

下位levelを上位levelの代用にしない。特にGoldenはTalkBack、日本語IME、実通信、
端末GPUの証跡にはならない。

## Golden baseline

- Compact: 390 x 844 logical pixels
- Large text: 200%
- Locale: `ja_JP`
- Theme: dark
- Motion: reduce motion
- Font: repositoryまたはrunnerで同一の日本語font
- Data: ownerを含まないdeterministic fixture
- File name: `qst_<id>_<screen>_<state>_<viewport>.png`
- Approval: candidate SHA、test name、fixture versionをQST Reportへ記録する

既存Goldenが条件を満たさない場合は、存在していても正式baselineへ数えない。

## Review cadence

10 QSTごとの横断レビューでmatrixを照合する。新しいPrimary screenや新しい状態を
追加した場合、同じQSTでmatrix、テスト、rollback説明を更新する。
