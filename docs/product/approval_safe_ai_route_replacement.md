# AI航路再作成の承認境界

## 目的

手動でMissionを作った後でも、Arcへ残りの航路を再設計してもらえるようにする。AI案はプレビューとして扱い、利用者の承認前に現在のMissionを変更しない。

## 適用ルール

1. Quest Planningは現在の未削除Missionを取得する。
2. 完了済みMissionは達成済み成果としてGeminiへ渡し、再生成対象から除外する。
3. 未完了の手動Missionは計画文脈として利用するが、AI案の承認時には残りの航路として置換できる。
4. AI案は既存航路の件数、状態、更新時刻を含むsnapshotとともに保存する。
5. プレビュー後にMissionが追加、編集、完了された場合、承認処理は`route_changed_since_preview`で全体をrollbackする。
6. 承認時は完了済みMissionを新しいactive Routeへ移し、未完了Missionを履歴として`removed`へ変更する。物理削除は行わない。
7. 完了済みMissionと同名のAI候補は承認しない。
8. `removed` Mission配下のTaskは通常のHome、Task一覧、Journey取得から除外する。

## UI

既存MissionがあるQuestでは航路ワークスペースへ「AIで残りの航路を作る」を表示する。生成開始後は候補パネルを主要領域へ展開し、候補確認時と確定時に、維持される完了済みMission数と置換される未完了Mission数を表示する。

## 失敗時

航路が変わっていた場合は最新状態から再生成する。Geminiや承認RPCに失敗しても、現在の航路とユーザー入力は変更しない。固定Missionへのfallbackは行わない。

## Hosted検証

MigrationとEdge Functionを同一candidate SHAから配備し、次を二アカウントで確認する。

- 所有者だけがpreviewを承認できる。
- 別アカウントのQuestへ適用できない。
- プレビュー後のMission変更で承認が拒否される。
- 完了済みMissionが新Routeへ引き継がれる。
- 未完了Missionは一覧から外れるがDB履歴に残る。
- 同じ承認を再送してもMissionが重複しない。

Hosted検証が完了するまではExternal Betaの完了証拠にしない。
