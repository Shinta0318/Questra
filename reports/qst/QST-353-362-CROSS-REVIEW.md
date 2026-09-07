# QST-353 to QST-362 Cross-Functional Review

Date: 2026-08-25  
Decision: Local implementation PASS / External Beta NO-GO

## Scope

QST-345〜352の前回横断レビュー結果を再確認したうえで、QST-353〜361をCode、UI/UX、AI、DB、Security、Privacy、Master Spec、Release Evidenceの観点から監査した。

## Fixed During Review

### High: Hosted Evidenceのclean判定が曖昧

`verify_hosted_evidence_bundle.dart`は対象文書に`working_tree_clean_at_`と任意の`true`があれば通過し得た。Project、RLS、Dual Accountごとに正しいfieldが`true`であることを個別検証するよう修正し、回帰テストを追加した。

### High: 参照用mock画像が製品bundleへ混入

`assets/mockups/`全体が`pubspec.yaml`へ登録され、未使用の設計資料6枚がアプリへ同梱されていた。auth/splashはruntimeの`arc_normal.png`へ統一し、mock directoryをbundle対象から除外した。参照資料とhash/provenance記録は削除せず保持する。

### Medium: 訂正依頼の短文入力が無反応

5文字未満で「依頼する」を押しても何も起きなかった。入力条件をhelper textで明示し、条件を満たすまでCTAをdisabledにした。Server側の5〜500文字制限は維持する。

## Area Review

| Area | Result | Evidence / remaining risk |
| --- | --- | --- |
| Trail sharing | Foundation pass | immutable selected-field snapshot、expiry、revocation、token hashあり。Recipient UX、abuse report、hosted RLSはQST-364。 |
| Guild pilot | Foundation pass | cohort gate、atomic copy、idempotencyあり。運用tool、moderation SLA、実測adoptionはQST-363。 |
| Premium | Boundary pass | Free Coreを維持し、Billing未実装。WTPと実AI原価が未検証。 |
| Rights / legal | Local pass | export、correction request、withdrawal、deletion reservationあり。処理SLA、provider retention、法務承認は未完了。 |
| Runtime evidence | Contract pass | PIIを持たないschemaあり。承認済みhosted sinkとalert drillは未実装。 |
| Hosted evidence | Automation pass | clean SHA拘束を強化。実projectでのcurrent SHA実行は未完了。 |
| Arc assets | Fail-closed pass | runtime bundleを7表情へ縮小。全assetのchain of titleは未確認のためPublic Releaseをblock。 |
| Master Spec | Pass | Arc中立性、ユーザー承認、非広告優先、挑戦データの本人管理を維持。 |

## Release Decision

次のすべてが実証されるまでExternal BetaはNO-GOとする。

- clean candidate SHAと同一project refのhosted migration/RLS/two-account evidence
- Android実端末の日本語IME、TalkBack、200% text、主要journey
- Data rights fulfillment、削除worker、backup/provider retentionの運用証拠
- Arc asset chain of titleとProduct/Legal承認
- privacy-safe hosted sink、SLO alert、rollback drill

## Next Ten-QST Direction

QST-363〜371でGuild pilot運用、Trail受信安全、runtime SLO、license、data-rights履行、asset package、観測sink、実端末証拠を閉じ、QST-372で再レビューする。
