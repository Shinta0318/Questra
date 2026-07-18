# Questra Beta データ利用説明 Draft

## Draft Status

この文書は内部Beta参加者向けの説明Draftです。正式なPrivacy Policyや利用規約ではなく、
外部配布前に運営主体、問い合わせ先、対象地域、保持期間、委託先条件を確定し、人による
法務確認を受ける必要があります。

## 保存するデータ

Supabase接続済みのBeta環境では、次のデータをアカウントに紐づけて保存します。

- nickname、email、Onboarding設定などのProfile情報。
- Quest、Mission、Trail、Reflectionと進捗情報。
- Arc Memory、Arc感情履歴、Tagなど、旅路を支える派生情報。
- Trailへ追加した画像とMedia metadata。

Supabase未接続のデモ環境では、一部機能は端末上の一時データで動作し、再起動後の保存を
保証しません。Privateな挑戦データをGuildや企業へ自動共有しません。

## Arcの生成時に処理するデータ

Remote生成が有効な場合、Arc ChatとQuest Guideは次のうち機能に必要な範囲をSupabase
Edge Functionへ送ります。

- Arcへ入力した内容と直近の会話。
- Active Quest、最近のMission・Trail。
- 関連度の高い少数のArc Memory。
- Quest Guideで対象となるQuestのtitle、description、category、difficulty、target date。

Edge Functionは、server側でGemini API keyが設定されている場合にGemini APIへこれらの
文脈を送ります。Gemini Interactions APIへのrequestは`store=false`で送信します。OpenAI互換経路は、
運営側がserver設定で明示的に選んだ場合だけ利用します。未設定、通信失敗、応答不備の場合は
local responseへ切り替わります。
生成内容は誤ることがあるため、医療、法律、金融、安全に関わる判断へそのまま利用しないで
ください。入力には秘密情報や第三者の個人情報を含めないでください。

## Betaフィードバックと障害情報

- SettingsのBeta feedbackは構造化reportをクリップボードへコピーします。Questraが
  自動送信したり、送信済みと扱ったりすることはありません。
- 外部Crash collectorは現在無効です。自動収集を開始する前に収集項目、保持期間、送信先を
  再レビューします。
- Crash証跡へQuest、Mission、Trail、Arc Memory、Arc Chat本文を含めません。
- 現在の内部Beta障害証跡は30日保持する運用です。Account、Quest、Mission、Trail、Arc Memory、
  Supabase backup、Gemini provider側の最終保持期間は外部配布前に確定します。

## 現在利用できない操作

このBeta buildでは、アプリ内からの全データexport、account全体のdelete、目的別consentの
保存・withdrawalは未提供です。公開前に本人確認を含む受付手続と問い合わせ先を用意します。

## 外部サービス

- Supabase: authentication、database、storage、Edge Functions。Beta projectのprimary regionは東京です。
- Gemini API: server設定時のArc Chat / Quest Guide生成。外部Beta前にpaid service、logging設定、
  provider retentionを確認します。
- OpenAI互換経路: 運営側がserver設定で明示した場合だけ利用します。

Analytics、Crash reporting、Paymentなど新しいproviderを追加する場合は、自動的に有効化せず、
この説明とPrivacy Policyを先に更新します。

## ユーザーへの約束

- Arc MemoryやPrivateな挑戦データをGuildや企業へ無断で共有しません。
- 企業支援が将来追加される場合、支援関係と利用目的を明示します。
- 生成結果や推定を事実として固定せず、訂正・削除できる設計を優先します。
- 成功だけでなく、継続、記録、再挑戦を尊重します。
