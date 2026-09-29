# Immutable Compensating AI Budget Correction

## Purpose

適用済みAI予算補正に誤りがあった場合、過去requestやauditを編集せず、別の補正requestで元のsnapshotへ戻す。相殺は利用者課金やPremium権利を変更する仕組みではなく、内部usage ledgerの監査整合を回復するためだけに使う。

## Contract

1. Reviewerが対象caseをclaimし、元の`applied` requestを選ぶ。
2. Serverはreservationをlockし、現在値が元requestの`corrected_*`と完全一致することを確認する。
3. 一致した場合だけ、`before_*`を現在値、`corrected_*`を元requestの`before_*`とした`pending_approval` requestを作る。
4. `compensates_request_id`で元requestを参照し、一つのrequestに対する重複相殺をDB制約で拒否する。
5. 別のauth-bound approverが既存のreview／apply transactionを使って承認・適用する。
6. Request作成時点ではreservation、counter、元requestを一切変更しない。

## Fail-closed rules

- 元requestが`applied`でなければ拒否する。
- Caseがopenでない、claimがない、leaseが切れている場合は拒否する。
- 現在snapshotが変わっていれば`budget_compensation_stale_snapshot`で全変更を拒否する。
- 同じidempotency keyの内容が異なる場合は拒否する。
- 同じ元requestへの二つ目の相殺は拒否する。
- Service Roleによる人間operatorのなりすまし経路は公開しない。

## Privacy

相殺requestとoperator eventにはtoken数、model、費用差、reason code、関係IDだけを保存する。Prompt、response、Quest、Mission、Trail、会話、検索文、利用者向け表示名は保存しない。

## Hosted verification

QST-447の専用candidate dataで、二人のauth operatorを使ってrequest、自己承認拒否、別人承認、apply、重複作成、stale snapshot、transaction rollback、並行作成を確認する。秘密情報と直接識別子は証跡へ残さない。
