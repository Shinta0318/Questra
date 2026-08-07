# Beta Privacy and Legal Copy Review

## Judgment

内部Beta向けのデータ・Arc生成説明は実装と整合する状態へ更新した。正式なPrivacy Policyと
Terms of Serviceは引き続きDraftであり、外部BetaまたはStore配布は人による法務確認、
運営主体・問い合わせ先・対象地域・保持期間の確定までBlockedとする。

## Implementation Audit

| Area | Actual behavior | Copy decision |
| --- | --- | --- |
| Persistence | 接続時はSupabase、未接続時はin-memory fallback | 保存保証の違いを明記 |
| Arc Chat | message、recent history、Quest/Mission/Trail/Memory contextをEdge Functionへ送信 | 外部処理範囲を明記 |
| Quest Guide | Quest detailをEdge Functionへ送信 | Guide生成対象を明記 |
| Model provider | Gemini Interactions APIが既定、OpenAIは明示互換 | provider、fallback、互換経路を明記 |
| Gemini storage | requestは`store=false` | server-side state保存を既定で無効化 |
| Gemini free tier | 内部検証では無料枠を使用 | 送信内容がGoogleの製品改善に利用され得ることを明記し、機密情報を禁止 |
| Supabase region | Questra BetaはTokyo (`ap-northeast-1`) | primary regionを明記 |
| Arc fallback | 未設定・失敗時はlocal response | 継続可能だがremote成功と誤認させない |
| Feedback | clipboard handoff | 自動送信しないと明記 |
| Crash capture | external provider disabled | 自動収集中と表現しない |
| Data requests | UIはpreview、実処理未提供 | export/delete/withdrawal未提供を明記 |

## Copy Rules

- 保存、生成時処理、共有、将来計画を混同しない。
- ArcをAI Assistantと呼ばず、生成機能とprovider利用を隠さない。
- 「匿名」「安全」「削除可能」など、実装と運用証跡のない断定をしない。
- Remote生成へ送るcontextを具体的に示し、機密情報・第三者情報を入力しないよう案内する。
- 生成結果は誤る可能性があり、高stakes判断は専門家や一次情報で確認するよう案内する。
- 外部provider追加前にPrivacy copy、retention、data processing条件を更新する。

## Review Basis

- 個人情報保護委員会は、保有個人データの利用目的や開示・訂正等の手続を本人が知り得る
  状態に置く考え方を示している。
  https://www.ppc.go.jp/personalinfo/legal/guidelines/
- Gemini APIはpaid/unpaid serviceでdata use条件が異なるため、外部Beta前にbilling状態を確認する。
  https://ai.google.dev/gemini-api/terms
- Gemini Interactions APIはrequest storageを設定でき、project logの保持期間も設定対象である。
  Questraはcode上`store=false`とし、AI Studio側logging設定も別途確認する。
  https://ai.google.dev/gemini-api/docs/logs-policy
- このレビューは法的助言ではない。対象地域と運営主体を確定したLegal Reviewerが最終判断する。

## Open Blockers

1. 運営会社・住所・代表者または正式なサービス提供者情報。
2. Privacy / support contactとdata request受付手順。
3. 対象地域、年齢条件、準拠法、紛争解決、consumer law確認。
4. Supabase DPA、subprocessor、backup retention（primary regionはTokyoで確認済み）。
5. 外部Betaで利用するGemini billing tier、project logging、provider retention、model/provider変更手順。
6. Account deletion、export、correction、consent withdrawalの実処理。
7. External Beta testerから取得する明示同意とversioned acceptance evidence。

## Exit Criteria

- Settingsで保存、Arc外部処理、Feedback、Crash、未提供操作を日本語で確認できる。
- Privacy DraftがSupabase、Gemini-first、conditional OpenAI互換利用を正確に示す。
- Terms Draftが生成結果の限界とhigh-stakes boundaryを示す。
- External distribution blockerとhuman legal review ownerが明示されている。

## Sign-Off Gate

`docs/qst/BETA_LEGAL_SIGNOFF.yaml`へversion、運営主体、contact、対象地域、保持条件、provider設定、
Product OwnerとLegal Reviewerの承認を記録する。秘密値や署名画像は保存しない。

```powershell
dart run tools/qst/verify_beta_privacy_copy_readiness.dart
dart run tools/qst/verify_beta_privacy_copy_readiness.dart --require-signoff
```
