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

- Arcの挨拶、今日のTaskと親Mission、進行中Quest、次の一歩を確認できます。
- Home -> Arc -> Questを中心に、今日進める内容へ移動できます。

### QuestとMission

- Questの作成、編集、詳細確認、進捗表示を利用できます。
- Arc GuideからMission候補を確認し、採用できます。
- Missionの作成・編集と、Missionに属するTaskの開始・完了を試せます。

### Arc

- Arc Chatで、進行中Quest、最近のMission・Trail、選ばれたArc Memoryを踏まえた
  応答を試せます。
- 外部生成が未設定または失敗した場合も、端末内の応答へ切り替わります。
- Arc Memory、Bond、Stardust、Navigator RankはBeta品質の体験として確認できます。

### Guild Discovery pilot

- 管理者がpilotを有効化した環境では、審査済みの公開QuestとMissionを発見できます。
- コピーは自分用の非公開下書きとして作成され、Arcによる個別最適化は承認後に行います。
- pilot停止中はGuild導線を表示せず、公開コミュニティ機能として扱いません。

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

- Guildの自由投稿、無審査公開、公開チャットは利用できません。Discovery pilotは
  審査済みsnapshot、段階配布、即時停止が有効な環境だけで提供します。
- JSON export、訂正依頼、同意撤回、account削除予約は接続済み内部Beta向けに実装済みですが、
  hosted二account検証と削除workerの運用証跡が揃うまで外部Betaでは有効化しません。
- Push通知、Signalの実通知、課金、Marketplace、企業支援は有効化していません。
- 外部クラッシュレポートは無効です。

## 既知の制約

1. `モックを開く`は開発者向けの端末内レビューです。Supabaseへ保存せず、再起動後の
   永続化も保証しません。外部Betaの動作証拠には使用できません。
2. Arcの生成内容は不完全または誤ることがあります。医療、法律、金融、安全に関わる
   判断では一次情報や専門家へ確認してください。
3. アプリアイコンと起動画面には最終デザインが未反映です。
4. 利用規約、Privacy Policy、Betaデータ利用説明は草案で、外部配布前の法務確認が未完了です。
5. 実機のカメラ、Media、キーボード、tablet、iOS検証は完了証跡が不足しています。
6. Guild Discovery pilotの表示有無は配布対象とFeature Flagにより異なります。

## Betaで確認してほしい航路

1. 案内されたBetaアカウントでログインする。
2. Onboardingを完了し、最初のQuestを作る。
3. Arc GuideからMissionを1件採用する。
4. Missionを編集し、Taskを実行して成果を確認する。
5. 完了した一歩をTrailとして残し、Timelineへ反映されることを確認する。
6. Arcへ次の一歩を相談する。
7. アプリを再起動し、同じアカウントでQuest、Mission、Task、Trailが残っていることを確認する。
8. 別アカウントから非公開のQuestが見えないことを運営担当者と確認する。

## Feedback

Settingsの`Betaテストの報告`から、画面、種類、S0-S3、再現手順、期待結果、実際結果を
入力してください。`レポートをコピー`はクリップボードへコピーするだけです。配布案内で
指定されたBeta窓口へtester自身が貼り付けてください。秘密情報、token、第三者の個人情報、
Arcとの会話全文はレポートへ含めないでください。

## テストを止める条件

- アプリが起動しない、またはHome / Quest / Mission / Task / Trail / Arcでクラッシュする。
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
