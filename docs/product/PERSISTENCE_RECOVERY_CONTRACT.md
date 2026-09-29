# Persistence Recovery Contract

## Purpose

Quest、Mission、Task、Trailの変更は、通信失敗を利用者の入力消失として見せない。
保存結果を正直に示し、同じ操作を安全に再試行できることを共通原則とする。

## User Contract

- `saving`: 操作を重複実行できないようにし、保存中であることを示す。
- `saved`: Remote保存を確認した後だけ成功を示し、短時間で閉じる。
- `failed`: 内部例外を表示せず、入力または復元済みデータの保持を明示する。
- `offline`: オフラインの可能性と、変更内容が保持されているかを別々に示す。
- `retry`: 同じentity IDと利用者入力で再送し、新しい入力へ固定値を混ぜない。
- `delete failure`: 楽観的に消したentityを画面へ戻してから再試行を提示する。

再試行可能な通知は誤って閉じられない。利用者が再試行、または各編集画面で
内容を修正するまで回復経路を残す。

## Domain Responsibilities

| Domain | Failure recovery |
| --- | --- |
| Quest | 最新の保存・削除操作を保持し、一覧の変更または復元済みQuestから再試行する |
| Mission | 最新の保存・削除操作を保持し、削除失敗ではMissionとQuest進捗を復元する |
| Task | owner-scoped durable queue、同一idempotency key、明示的な再試行／破棄を維持する |
| Trail | 作成・編集sheet内のdraftと同一Trail IDを保持する。一覧読込だけ共通Bannerから再試行する |

Taskのdurable queueを単純な画面内retryへ格下げしない。Trail作成はdraft repositoryと
sheet内の明示再送を正本とし、一覧Bannerから二重保存を起こさない。

## Concurrency and Ownership

- 古い成功応答は、それより新しい失敗操作のretry slotを消してはならない。
- owner切替時はretry slotと同期表示を破棄し、別ownerへ変更内容を持ち越さない。
- Repositoryのupsertまたはidempotency contractを維持し、再送でentityを複製しない。
- RLSとHosted二アカウント証跡はローカルWidget Testで代替しない。

## Evidence Boundary

ローカルテストは入力保持、復元、再試行、競合応答順を証明する。実ネットワーク切断、
プロセス再起動、Hosted Supabase、Android物理端末での復旧は外部証跡として別途確認する。
