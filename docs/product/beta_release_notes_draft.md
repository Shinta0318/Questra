# Questra Internal Beta Release Notes Draft

## Build

- App version: `1.0.0+1`
- Channel: Internal Beta
- Candidate commit: Release Managerが配布時に記入
- 対象: 承認済みBeta testerのみ

このビルドは公開版ではありません。実データを使う前に、配布案内に記載されたSupabase
環境とテストアカウントを確認してください。

## 今回試せること

### Home

- Arcの挨拶、今日のMission、進行中Quest、次の一歩を確認できます。
- Home -> Arc -> Questを中心に、今日進める内容へ移動できます。

### QuestとMission

- Questの作成、編集、詳細確認、進捗表示を利用できます。
- Arc GuideからMission候補を確認し、採用できます。
- Missionの作成、編集、並べ替え、今日のMission設定、完了を試せます。

### Arc

- Arc Chatで、進行中Quest、最近のMission・Trail、選ばれたArc Memoryを踏まえた
  応答を試せます。
- 外部生成が未設定または失敗した場合も、端末内の応答へ切り替わります。
- Arc Memory、Bond、Stardust、Navigator RankはBeta品質の体験として確認できます。

### Trail

- 完了したMissionやQuestの進捗をTrailとして残し、Timelineで振り返れます。
- 画像の追加、差し替え、削除はQST-204の実機・Storage検証が完了するまで試験中です。

### ProfileとSettings

- Profileで旅路の状態と所有者情報を確認できます。
- Settingsでデータの保存・外部処理、Arc Memory、目的別同意の設計を確認できます。
- Betaフィードバックレポートを作成し、クリップボードへコピーできます。

## 試験中の機能

- Supabase Auth、Profile、Quest、Mission、Arc Memoryの永続化は、接続済みBeta環境で
  実機証跡を集めている段階です。
- RLSにはmigrationと検証harnessがありますが、配布先Supabase projectでのアカウント分離を
  Release Managerが確認する必要があります。
- Arcの外部生成はSupabase Edge Functionとserver側provider設定に依存します。
- 小画面、tablet、web向けresponsive testは自動化済みですが、実機QAは継続中です。
- TrailのMedia永続化は接続済みBeta環境とAndroid/Webで証跡を取得している段階です。

## 現在利用できない機能

- Guildは主なナビゲーションではComing Soonです。Discovery、参加、投稿、Moderationの
  実環境検証が完了するまで、このBetaの主要導線には含めません。
- 全データのエクスポート、アカウント全体の削除、目的別同意の保存・撤回は未提供です。
- Push通知、Signalの実通知、課金、Marketplace、企業支援は有効化していません。
- 外部クラッシュレポートは無効です。

## 既知の制約

1. Supabase未接続では一部データがメモリ上で動き、再起動後の保存を保証しません。
2. Arcの生成内容は不完全または誤ることがあります。医療、法律、金融、安全に関わる
   判断では一次情報や専門家へ確認してください。
3. アプリアイコンと起動画面には最終デザインが未反映です。
4. 利用規約、Privacy Policy、Betaデータ利用説明は草案で、外部配布前の法務確認が未完了です。
5. 実機のカメラ、Media、キーボード、tablet、iOS検証は完了証跡が不足しています。
6. Guildを含む旧チェックリストは、今回の主なBeta導線と一致しない場合があります。

## Betaで確認してほしい航路

1. 案内されたBetaアカウントでログインする。
2. Onboardingを完了し、最初のQuestを作る。
3. Arc GuideからMissionを1件採用する。
4. Missionを編集し、今日のMissionとして完了する。
5. 完了した一歩をTrailとして残し、Timelineへ反映されることを確認する。
6. Arcへ次の一歩を相談する。
7. アプリを再起動し、同じアカウントでQuest、Mission、Trailが残っていることを確認する。
8. 別アカウントから非公開のQuestが見えないことを運営担当者と確認する。

## Feedback

Settingsの`Betaテストの報告`から、画面、種類、S0-S3、再現手順、期待結果、実際結果を
入力してください。`レポートをコピー`はクリップボードへコピーするだけです。配布案内で
指定されたBeta窓口へtester自身が貼り付けてください。秘密情報、token、第三者の個人情報、
Arcとの会話全文はレポートへ含めないでください。

## テストを止める条件

- アプリが起動しない、またはHome / Quest / Mission / Trail / Arcでクラッシュする。
- 保存成功表示の後にQuestやMissionが失われる。
- 別アカウントの非公開データが表示される。
- Arcへの入力や非公開の旅路データが意図しない場所へ表示される。
- S0レポートが未解決のまま残っている。

該当した場合は操作を続けず、S0としてRelease Managerへ報告してください。

## Related Guides

- Account setup: `docs/product/beta_account_setup_flow.md`
- Feedback: `docs/product/beta_feedback_operations.md`
- Data and Arc generation: `docs/legal/beta_privacy_notice_ja_draft.md`
- Device validation: `docs/product/real_device_beta_validation.md`
