# QST-347 追加受入条件: 意味ある行動の実測

- ID: QST-347（新番号ではない）
- Priority: P1 / High（公開前に計測契約、公開後に実測）
- Finding: LA-06
- Status: 既存`Validated / local_verified`を否定しない。イベント分類だけで定着計測完了とはしない。
- 上位原則: Master Spec v2.1、Design Bible v2 Today Focus / Trust

## 背景・ユーザー問題・目的

`analytics_event.dart`にはmeaningful progress等の名前があるが、`QST-347.md`は画面発火点と集計をFollow-Upとしている。ユーザーがQuestを続けているか、AI障害後に戻れるかをDAU以外で測る。改善効果を実測せずQSTだけ増やさないための計測契約を完成する。

## 対象・非対象・依存

対象: Task開始/完了、Quest→最初の行動、停滞後/再計画後の再開、Trail記録、提案の採用/編集/拒否、AIコストのイベント発火点と集計。想定ファイル: `core/analytics/analytics_event.dart`、`analytics_service.dart`、Task/Quest/Trail/Route操作層、集計SQLまたは安全な分析処理、`docs/analytics`、テスト。非対象: 生会話の保存、個人別ランキング、強制通知、課金の即時導入。依存: QST-261のTask正本、QST-525のHosted owner境界、同意目的管理。

## UI/UX・日本語・Accessibility・データ・AI・Security

- 計測のために追加タップ/入力を要求しない。ユーザー向け分析説明は「進み方の改善に使う」等、用途を簡潔に日本語で示す。
- 同意がない目的の収集は行わず、設定から停止・撤回できる。Arcの回答やTrail本文、Quest名、URL、メールなどを送らない。
- event_id/idempotency_key、owner、quest/mission/taskの安全な参照、操作時刻、環境、schema versionだけで集計できる設計にする。二アカウントRLSと小集団の再識別防止を検証する。
- Gemini呼出回数と費用はoperation/model/passごとに集計し、prompt/response本文を保持しない。

## Analytics契約

定義の正本は監査レポート第8章。初回24h Task完了率は「Quest作成したユニークownerを分母、24h以内に配下Taskを初完了したownerを分子」。Weekly Meaningful Actionは閲覧ではなくTask完了/成果確認/Trail/承認済み再計画のみ。D1/D7/D30は初回Quest作成コホート、停滞後再開率は停滞と同じQuestの次Task開始で判定する。モック/内部QAは本番指標から除く。集計可能数に達する前に数値目標を創作しない。

## 受入条件・Negative Test

- 正常系: Task開始/完了で正本の操作が成功した後に一度だけイベント、24h/WMA/D7等が同じfixtureで再計算可能。Quest削除/一時停止は分母で明示的に扱う。
- 失敗系: offline再送、画面再表示、二重tap、応答喪失で重複しない。分析保存失敗はTask操作を失敗にしない。
- Negative: 未保存操作、mock、本人以外のデータ、生本文、未同意目的、小集団の個別開示を排除する。
- Responsive/Localization: 計測同意/撤回表示は320〜430px、200%文字、日本語/英語、読み上げで理解可能。
- 性能: 計測は非同期、Task完了UIを待たせない。集計はbounded query/期間分割で行う。

## 段階公開・Rollback・証拠・残余リスク

internal→同意済みBeta cohort→集計公開の順。異常時は収集をfeature flagで止め、Task機能は継続。誤集計データは追跡可能なevent versionで再集計する。完了証跡はイベント発火点テスト、重複/同意/owner/RLSテスト、fixtureに対する集計表、プライバシーレビュー、Hosted匿名集計。残余リスクは端末時計のずれ、分析同意による選択バイアス、少数コホート。時刻正規化と分母注記で抑える。
