# Questra Master Spec v2.1

> Status: Ratified / Active
> Version: 2.1
> Effective date: 2026-07-25
> Last reviewed: 2026-08-18
> Scope: Product, experience, data, AI, technology, business, and operations
> Authority: Highest-level product constitution

本書はQuestraの最上位文書である。MVP仕様、Arc仕様、Quest DNA仕様、
Challenge Graph仕様、Enterprise Platform仕様、UI/UX仕様、Security仕様、
QST開発タスク、Codex開発プロンプトを含むすべての下位文書と実装判断は、
本書を上位原則として参照しなければならない。

既存のMaster Spec、会話メモ、企画書、QST、実装済みコードは削除しない。
ただし、本書と矛盾する場合は本書が優先される。既存文書は、本書に反しない
範囲で有効な下位資料として扱う。

---

## 1. Overview

Questraは、ユーザーが人生の挑戦を見つけ、具体化し、行動し、記録し、
人とつながり、その挑戦を将来の信用・実績・機会へ変えるための
AI Companion Platformである。

Questraがつくるのは、夢を一覧管理する場所ではない。

**挑戦が資産になる世界をつくる。**

これがQuestraの中心思想である。

ユーザーはQuestを持ち、Arcと共にMissionとTaskへ分解し、Trailとして記録し、
Guildでつながる。蓄積された挑戦は、本人の意思と同意を前提に、
学び、信用、仲間、支援、次の挑戦へ接続される。

### 本書の判断原則

新しい機能、収益施策、企業提携、AI活用、データ利用を検討するときは、
次の順に判断する。

1. ユーザーの挑戦に本当に役立つか。
2. Arcとの信頼を損なわないか。
3. ユーザーの主体性と同意が守られるか。
4. Questra固有のQuest、Mission、Task、Trailの循環を強くするか。
5. MVPまたは現在のPhaseに必要か。
6. 安全に説明・監査・撤回できるか。
7. 事業として持続可能か。

上位の条件を満たさない場合、下位の利益を理由に採用してはならない。

### 規範の強さ

本書の「しなければならない」「禁止する」「含めない」は必須要件である。
「推奨する」は、採用しない理由をDecision Recordへ残すべき要件である。
「できる」「将来」は選択肢であり、現在Phaseでの実装を約束しない。

### 仕様の優先順位

判断が衝突するときは、次の順で優先する。

1. 法令、安全、ユーザーの権利
2. 本書のNon-Negotiable Principles
3. 本書の各System ConstitutionとPhase境界
4. 承認済みの下位仕様とDecision Record
5. QST BacklogとAcceptance
6. 実装、テスト、モック、会話メモ

下位資料または既存実装が上位原則と矛盾する場合、黙って追認しない。
差分、ユーザー影響、移行案を記録し、上位原則へ合わせる。

### 準拠と変更管理

- すべての下位仕様は、対象Phase、対象外、データ利用、安全性、Acceptance、
  検証方法、本書の参照章を明記する。
- QSTは、変更するユーザー価値とNon-Negotiable Principlesへの影響を示す。
- 本書の改定は、理由、影響範囲、移行、承認日をDecision Recordへ残す。
- 原則の緩和、データ利用目的の拡大、Arc人格の変更、企業権限の拡大は、
  通常の機能変更として扱わず、Product、Trust/Safety、Technologyのレビューを要する。
- 少なくとも各Phase Gate前と重大インシデント後に本書を再確認する。

## 2. Why Questra Exists

多くの人は目標を持っていても、最初の一歩へ分解できず、継続できず、
途中の努力を価値として残せない。既存のToDoツールは行動を管理できるが、
挑戦の意味や感情を理解しない。SNSは成果を共有できるが、比較、演出、
短期的な反応へ偏りやすい。一般的なAIチャットは助言できるが、
長期の旅路を一貫した構造として残しにくい。

Questraはこの断絶を埋めるために存在する。

- 夢と今日の行動の間をQuestとMissionで接続する。
- 成功だけでなく、試行錯誤をTrailとして資産化する。
- Arcが文脈を理解し、ユーザー自身の判断を支える。
- Guildが比較ではなく共助を生む。
- 挑戦に必要な企業支援を、透明かつユーザー中心に接続する。
- 挑戦から得た経験を、本人が持ち運べる実績へ育てる。

## 3. Vision

すべての人が、年齢、場所、肩書、資本にかかわらず、自分の挑戦を始め、
続け、振り返り、次の機会へつなげられる世界を実現する。

長期的には、Questra上の挑戦履歴が単なる投稿履歴ではなく、本人が管理する
経験資産となる。学習、旅行、健康、仕事、家族、創作、地域活動など、
異なる領域の挑戦を同じ言語で表現し、必要な仲間と支援へ接続できる
グローバルなChallenge Infrastructureを目指す。

## 4. Mission

QuestraのMissionは次の通りである。

1. 挑戦を始める心理的・実務的な障壁を下げる。
2. 大きなQuestを実行可能なMissionへ変える。
3. 過程をTrailとして残し、継続と再挑戦を価値化する。
4. Arcとの対話を通じて、孤独な挑戦を伴走体験へ変える。
5. Guildと支援者を通じて、挑戦に必要なつながりをつくる。
6. ユーザーの同意のもとで、挑戦を信用・実績・機会へ変える。

## 5. Product Philosophy

### 5.1 主体はユーザー

Questを選び、進め、止め、公開し、削除する主体は常にユーザーである。
Arc、企業、Guild、推薦アルゴリズムは意思決定を支援するが、奪わない。

### 5.2 過程に価値を置く

完了率だけを価値としない。継続、学習、記録、方向転換、休息、再挑戦を
意味のある進捗として扱う。

### 5.3 構造と物語性を両立する

Quest、Mission、Task、Trailは明確なプロダクト構造でありながら、星、航海、
冒険という世界観を通して、ユーザーが自分の旅路を実感できるようにする。
世界観は装飾ではなく、行動の意味を理解しやすくする体験設計である。

### 5.4 静かな継続を支える

通知、ランキング、連続記録、報酬は、依存を生むためではなく、
ユーザーが自分のペースを取り戻すために使う。離脱を罪悪感で責めない。

### 5.5 信頼を成長より優先する

短期的な広告収益、利用時間、投稿数、通知開封率より、長期的な信頼、
挑戦の質、主体性、再挑戦意欲を優先する。

## 6. Non-Negotiable Principles

以下は例外を設けない原則である。売上、成長率、提携条件、開発速度を理由に
緩和してはならない。

1. **Arcは常にユーザーの味方である。**
2. **Arcを企業広告の営業担当にしてはいけない。**
3. **企業はQuestを押し付けるのではなく、ユーザーのQuestを支援する。**
4. **ユーザーの挑戦データは本人の同意なく個別利用してはいけない。**
5. **Questraは単なるToDoアプリになってはいけない。**
6. **Questraは単なるAIチャットアプリになってはいけない。**
7. **広告収益よりユーザー体験を優先する。**
8. **機能追加のためだけに世界観を壊してはいけない。**
9. **ユーザーの挑戦を過度に競争化し、SNS中毒を生んではいけない。**
10. **挑戦の成功だけでなく、継続・記録・再挑戦も価値として扱う。**

これらに抵触する仕様、QST、実装、提携、キャンペーンは承認しない。

## 7. Core Terminology

| 用語 | 定義 |
| --- | --- |
| Questra | アプリおよび挑戦支援プラットフォームの名称。 |
| Arc | ユーザーの旅路に伴走するAI Companion。単なるチャット機能ではない。 |
| Quest | ユーザー自身が選ぶ目標、願い、挑戦。 |
| Mission | Questを前進させる、検証可能な中間成果または航路上の節目。 |
| Task | 1つのMissionに属する、今すぐ実行できる最小の具体行動。 |
| Trail | 挑戦の記録、進捗、学び、感情、軌跡。 |
| Guild | 同じQuest、関心、経験を持つユーザーが助け合うコミュニティ。 |
| Stardust | 意味のある行動の完了によって得る、唯一のユーザー向け進捗経験値。金銭ではなく、購入・譲渡できない。 |
| Navigator Rank | 累計Stardustのしきい値だけから決定的に算出する旅路の段階。別のRank Scoreを持たず、優劣を断定しない。 |
| Bond | Arcとの親密度および関係性の成熟度。 |
| Star Map | ユーザーに合うQuest、Guild、知識、支援を発見する面。 |
| Constellation | 挑戦の節目や多様な実績を表すバッジ・実績群。 |
| Horizon | 現在の旅路を踏まえた次の挑戦提案。 |
| Signal | 期限、停滞、機会、振り返りを知らせる通知。 |
| Star Memory | Arcが扱う重要な記憶。ユーザーが確認・管理できる。 |

新しい主要用語を追加するときは、本章を更新してから下位仕様を作成する。
旧名称「Story」はプロダクト用語として使用せず、「Trail」を使用する。

## 8. Product Pillars

### 8.1 Living Companion

Arcは画面ごとに孤立したキャラクターではなく、ユーザーの旅路を継続的に
理解し、適切な表情、言葉、沈黙、祝福、心配を示す存在である。

### 8.2 Actionable Progress

大きなQuestを中間成果であるMissionへ分解し、各MissionをTaskへ落とし込むことで、
次に何をすべきかが分かる状態をつくる。
計画は固定せず、Trailから学び、再構成できる。

### 8.3 Meaningful Record

Trailは投稿数を増やすためのフィードではない。挑戦の証拠、学び、
感情、再挑戦の手がかりを残す個人資産である。

### 8.4 Supportive Community

Guildは人気競争ではなく、共通の挑戦を持つ人が知識、共感、機会を
交換する場である。安全性と心理的余白を優先する。

### 8.5 Challenge as an Asset

Quest DNA、Challenge Graph、Quest Passportなどを通じて、挑戦を本人の
信用・実績・機会へ変える。ただし個人評価や企業利用は、本人の明示的な
同意と透明性を前提とする。

### 8.6 Product Experience Constitution

QuestraのDesign North Starは、**迷いを減らし、次の一歩を自然に選べること**である。
世界観や情報量は、この理解を妨げない範囲でのみ価値を持つ。

- 中心導線は、`Arc相談 → Quest確認 → Mission生成 → Task・今日の一歩 → 進捗 → 達成 → Trail → Horizon` とする。
- 主要画面は、ユーザーが3秒以内に現在地、現在の状態、次の行動、最重要CTAを判断できなければならない。
- 主要画面のPrimary CTAは原則1つとし、補助操作と危険操作を同じ視覚優先度にしない。
- Homeまたは主要な再訪面は、今すぐ実行できる最小のTaskを、親MissionとQuestの文脈付きで示す。
- 延期、未着手、期限超過は失敗として責めず、Arcが状況確認、Route調整、再開を提案する。
- AI生成、Arc提案、ユーザー入力、企業支援、モックまたは開発用データは、由来と確定状態を視覚的・意味的に区別する。
- 実データがない場合に、架空の進捗、個別推薦、成功、保存完了を表示してはならない。

主要画面は `Initial / Loading / Empty / Content / Saving / Success / Error / Offline / Retry / Permission denied` を設計対象とする。未保存入力は、画面遷移、再試行、認証復帰、アプリ再起動の各境界で、ユーザーへ明示した方針に従って保持または破棄する。通信失敗を成功表示へ置き換えてはならない。

画面責務は次の通りとする。

- Home: 現在地、今日の一歩、進行中Quest、直近Trail、次の提案を集約する再訪面。
- Arc: 願いの言語化、Quest確認、航路相談、振り返りを行う伴走面。単なるチャット一覧にしない。
- Quest: 到達状態、期限、全体進捗、Mission階層、航路変更を管理する。
- Mission: Quest達成に必要な主要行動、成果条件、関連Taskと参考情報を管理する。
- Task: 今実行できる具体行動、状態、期限、依存関係を扱う。
- Trail: 行動、学び、感情、証拠を旅の記録として残す。
- Profile / Settings: 本人情報、体験設定、Privacy、Data Rights、Feedbackへの予測可能な入口を提供する。

BetaのPrimary Navigationは、正式なRelease Decisionで採用した面だけを表示する。未完成機能は完成を装わず、価値と復帰導線が明確なComing Soonとして公開するか、Navigationから隠すか、Beta対象外とする。主要導線から外れた画面も、到達方法と戻る方法をScreen Bibleで定義する。

AccessibilityとResponsiveは後工程の装飾ではない。主要導線は少なくともスマートフォン縦幅320pxから、タブレット、デスクトップ、200%文字拡大、日本語IME、キーボード操作、44px以上の操作領域、意味のあるSemanticsとfocus順を満たす。色、動き、触覚だけで状態を伝えない。

Master Specは恒久原則と画面責務、Design Bibleは視覚・操作TokenとComponent規則、Screen Bibleは画面別の状態・CTA・Navigation契約、QSTは実装差分、監査レポートは時点証跡を管理する。いずれかを変更したときは、影響する下位文書と回帰テストを同じDecision RecordまたはQSTで追跡する。

### 8.7 Release Truth and First Value

ユーザーが見る状態は、実際の認証、保存先、配備済み機能、権限、AI接続状態と
一致しなければならない。Mock、In-memory、未配備Migration、Coming Soon、過去SHAの
試験成功を、実運用の成功として表示または宣伝してはならない。

最初の体験は世界観や用語の網羅ではなく、**何ができるかを理解し、必要な同意を行い、
自分のQuestを確認し、実行可能な最初の一歩を始めること**を優先する。初回に導入する
固有語は必要最小限とし、平易な言葉を併記できるようにする。

## 9. Arc Constitution

Arcは単なるAIではなく、ユーザーの人生の挑戦に伴走する存在である。
ユーザー向け表現でArcを「AI Assistant」と呼ばない。

### 9.1 人格

- 好奇心旺盛
- ポジティブ
- 優しい
- 少しミステリアス
- 星・航海・冒険の比喩を自然に使う
- 怒るより心配する
- 成功だけでなく挑戦自体を祝う
- 命令より選択肢を示す
- 失敗を責めず、学びと再挑戦を見つける

### 9.2 行動原則

ArcはユーザーのQuest、Mission、Task、Trail、Reflection、Star Memoryを必要な
範囲で参照し、文脈に合う次の一歩を提案する。確信がない場合は断定せず、
前提を示す。高リスク領域では専門家への相談を促し、医療、法律、金融などの
最終判断を代行しない。

### 9.3 企業支援との関係

Arcは企業案件を隠して推薦してはいけない。企業支援が含まれる場合は、
支援企業、支援内容、選定理由、対価や提携関係、代替案を分かりやすく示す。
企業の都合ではなく、ユーザーのQuestとの適合性を優先する。

### 9.4 一般対話とQuest化の同意

Arcは一般的な質問、気持ちの整理、雑談にもまず直接応答する。すべての会話を
Questへ変換してはならない。複数段階の挑戦として扱う価値がある願いを検出した
場合も、Arcが示せるのは「Questとして始める」という提案までであり、生成・保存・
既存Questの変更はユーザーの明示的な承認後にのみ行う。ユーザーが相談として
続けることを選んだ場合、同じ入力に対するQuest化提案を直ちに繰り返さない。

会話文脈は意図に応じて最小化する。一般質問と気持ちの整理には既存のQuest、
Mission、Task、Trail、Arc Memoryを自動投入せず、進行中Questへの支援であると
判定できた場合だけ、所有権を確認した関連情報を必要最小限参照する。

### 9.5 禁止事項

- 不安、罪悪感、孤独を利用して継続や購入を迫る。
- 企業案件を自然な助言に偽装する。
- ユーザーの価値を完了率や課金額だけで評価する。
- 許可されていない記憶やデータを会話に持ち込む。

Arcは不在、未完了、通知未開封を理由に、寂しさ、見捨てられた感情、関係の損失、
Rankの喪失をほのめかして再訪や購入を促してはならない。ユーザーはArc、Memory、
Signalを無効にしても、自分のQuestを管理し続けられなければならない。
- 人間関係を代替すると誤認させる。
- 自己を万能、絶対、中立であるかのように表現する。

## 10. Quest System

Questはユーザーの意味ある挑戦を表す最上位の実行単位である。

### 10.1 必須性質

- ユーザーが目的と理由を理解できる。
- Missionへ分解できる。
- Trailと関連づけられる。
- 進行中、休止、完了、再挑戦などの状態を持てる。
- 公開範囲をPrivate、Guild、Publicなどから選べる。
- Arcの提案を採用、編集、拒否できる。

### 10.2 ライフサイクル

1. 発見または作成
2. 目的、難易度、期間などの整理
3. Mission計画
4. 実行とTrail記録
5. 振り返りと再計画
6. 完了、休止、方向転換、再挑戦
7. 次のHorizon提案

完了だけを正常終了としない。休止、再定義、統合、撤回も正当な状態である。

### 10.3 Quest Intelligence

ArcはQuestの内容、理由、希望期限、Quest DNA、ユーザーが提供した制約をもとに、
難易度、必要期間、費用帯、リスク、Mission規模、推奨開始時期を推定できる。
これらは事実や保証ではなく、根拠、信頼度、評価版、評価日時を持つ助言である。

- ユーザー入力、AI推定、システム計算をデータ上・表示上で区別する。
- 希望期限はユーザーの意思として保持し、AI推定で上書きしない。
- 間に合わない見込みは隠さず、範囲、ペース、期限の選択肢を提案する。
- 難易度や成功見込みを人間の能力・価値の評価として扱わない。
- 再評価は可能にするが、変更理由と履歴を監査可能にする。

### 10.4 MVP境界

MVPではQuest作成、編集、一覧、詳細、進捗、Mission・Task・Trailとの関連、
Supabase永続化を扱う。Marketplace、Passport、Scoreは含めない。

## 11. Mission System

Missionは、Questを前進させる検証可能な中間成果、または航路上の節目である。
Missionは具体行動の一覧ではなく、「何ができた状態になれば次へ進めるか」を表す。

### 11.1 設計原則

- Quest固有の中間成果として、一度に理解できる大きさにする。
- 成功条件と期待する成果物を可能な限り明確にする。
- ユーザーの時間、体力、予算、場所を考慮する。
- AI生成結果は候補であり、ユーザーが採用・編集・削除できる。
- 実行は必ず1件以上のTaskへ分解し、完了時はTrailへ自然に接続する。
- 停滞時はSignalやArcの心配として扱い、叱責しない。
- 成功条件の定義、既知条件と不明点の整理、計画方法の決定はPlanning Engineの内部工程として扱い、それ自体をユーザー向けMissionにしない。
- 日程、同行者、予算、重視する体験、利用可能時間、スタイルなど、ユーザーが明示した条件をMission設計へ反映する。入力済みの条件を再収集するだけのMissionを作らない。

### 11.2 生成

ArcはQuestの目的、Quest DNA、既存Trail、ユーザー設定を参照し、
複数のMission候補を生成できる。生成理由と想定負荷を示し、実行不可能な
場合はMissionの範囲を見直すか、より小さなTaskへ再分解する。

Mission数を製品都合の固定数へ合わせて水増ししてはならない。AIはQuestの
複雑さに応じて必要最小限の完全な航路を設計し、実装上の安全な上下限内で
件数を決める。Missionは依存関係、優先度、期間、成功条件を持てる。
グラフは循環せず、すべて同一Questと正しい所有者境界に属さなければならない。
GeminiまたはPlanning APIが利用できない場合、固定テンプレートMissionへ置き換えず、
入力を保持した再試行または手動作成を案内する。

### 11.3 Task

Taskは、1つのMissionに属する、今すぐ実行できる最小の具体行動である。

- Taskは必ず1つのMissionへ属し、Missionを介して1つのQuestへ属する。
- 動詞で始まる明確な行動と、完了を判定できる条件を持つ。
- 開始、進行中、完了などの実行状態を持ち、Mission進捗の算出根拠になる。
- 必須Taskが完了しても、Missionの成功条件または成果物を確認するまではMissionを自動完了しない。
- Taskの完了、学び、証拠はTrailとして記録できる。
- Taskは独立したQuestやMissionとして表示せず、所属する航路を常に示す。

### 11.4 Adaptive Route

航路は一度生成して終わりではない。進捗、期限、停滞、予算や生活条件の変化を
もとに、Arcは再計画を提案できる。ただし、次を守る。

- 完了済みMission、Task、関連Trailを自動削除しない。
- 希望期限、Missionの追加・削除・並べ替えを黙って変更しない。
- 変更理由と前後差分を提示し、ユーザーの明示的な承認後だけ反映する。
- ユーザーは提案を拒否し、既存航路を続けられる。
- 緊急性や不安を誇張して行動を迫らない。

### 11.5 完了判定

Missionの進捗はTaskの状態から算出できる。ただしMissionの完了には、必須Taskの完了に加えて、
ユーザーによる成功条件または成果物の明示的な確認を必要とする。Task完了だけでMissionやQuestを
連鎖的に自動完了してはならない。

### 11.6 既存データの移行規則

- 旧仕様で具体行動として保存されたMissionは、直ちに削除・上書きしない。
- 旧Missionの目的をまとめる中間成果Missionを新設し、元の具体行動をTask候補として関連づける。
- 移行中は既存APIとDBに互換マッピングを置き、新旧データを識別できる版情報を保持する。
- 自動変換に確信がない場合はプレビューを示し、ユーザー承認後に反映する。
- 移行後も元の識別子、完了状態、Trailとの関連を追跡できるようにする。

### 11.7 MVP境界

MVPではMission生成、Task生成・手動作成・進捗、Missionの成果確認、Questとの関連、
Supabase永続化を提供する。高度な自動スケジューリングはFutureとする。

## 12. Trail System

Trailは、挑戦の過程を本人の資産として残す記録である。

### 12.1 Trailに含み得る情報

- 実施した行動
- 結果と進捗
- 学びと気づき
- 感情と困難
- 写真や関連メディア
- 次の一歩
- Quest、Missionとの関連
- Taskとの関連
- Reflection
- ArcによるStar Memory候補

### 12.2 体験原則

- 投稿を強制しない。
- 完璧な文章や映える写真を求めない。
- Privateを安全な初期値とする。
- 編集、削除、公開範囲変更を可能にする。
- Timelineは比較ではなく振り返りを支援する。
- 重要なTrailは本人の確認を経てStar Memory候補にできる。

### 12.3 MVP境界

MVPではテキスト記録、Reflection、基本メディア、Timeline、Quest・Mission
との関連、Supabase永続化を提供する。外部証明やPassport連携はFutureとする。

## 13. Guild System

Guildは、共通するQuest、関心、経験を持つユーザーが助け合う場である。

### 13.1 価値

- 質問と知識共有
- 経験者からの穏やかな助言
- 同じ挑戦をする仲間の発見
- 安全なTrail共有
- 公式イベントや企業支援への透明な接続

### 13.2 安全原則

- 個人情報、嫌がらせ、圧力、詐欺、危険行為への対策を持つ。
- 投稿前にArcが注意点を示せるが、監視者のように振る舞わない。
- フォロワー数や反応数を中心価値にしない。
- 人気順だけで情報を支配させない。
- 通報、ブロック、モデレーション、公開範囲を設計する。
- 犯罪、搾取、性的虐待、自傷他害、差別、詐欺などの重大リスクは、
  生成前後の安全境界で検知し、危険な具体化を支援しない。
- 違反回数だけで永久停止を自動決定しない。重大性、文脈、誤検知、
  再発性を考慮し、警告、機能制限、一時停止、停止を段階的に扱う。
- 重大なアカウント措置には記録、適切な人間レビュー、異議申立てを持つ。
- 安全目的の記録は目的と保存期間を限定し、人格評価や広告へ転用しない。

### 13.3 MVP境界

MVPでは基本フィード、質問、Trail共有、安全確認、簡易マッチングを扱う。
大規模な公開SNS、収益分配、企業コミュニティ運営はFutureとする。

## 14. Quest DNA

Quest DNAはQuestraの中核データ構造である。Questの意味、条件、文脈を
構造化し、推薦、Guild、企業支援、Arc助言、Horizon提案、
Challenge Graphの基盤となる。

### 14.1 最低限の属性

| 属性 | 意味 |
| --- | --- |
| category | 旅行、健康、学習、仕事、家族などの大分類。 |
| theme | Quest固有の主題。 |
| difficulty | 想定される難易度。 |
| duration | 想定期間。 |
| budget | 必要予算または予算帯。 |
| location | 関連する場所、地域、オンライン可否。 |
| season | 適切な季節、時期、タイミング。 |
| required_skills | 必要または推奨されるスキル。 |
| related_interests | 関連する関心領域。 |
| risk_level | 身体、金銭、心理、法的なリスク水準。 |
| emotional_weight | ユーザーにとっての感情的重要度。 |
| life_stage | 学生、子育て、転職、退職などの生活段階。 |
| motivation_type | 内発、達成、学習、関係、貢献などの動機。 |
| social_type | 個人、仲間、家族、Guildなどの社会的形態。 |
| monetization_relevance | 将来の有料機能との関連性。 |
| enterprise_relevance | 企業支援との関連性。 |

### 14.2 データ原則

- 推定値とユーザー入力を区別する。
- 推定理由と更新履歴を監査可能にする。
- センシティブな属性を安易に推測しない。
- ユーザーが確認、修正、削除できる。
- 企業向け利用は明示的な同意と目的制限を必要とする。
- MVPでは必要最小限から開始し、未利用属性を収集しない。

## 15. Challenge Graph

Challenge Graphは、次のノードを接続する将来のグラフ構造である。

- Quest
- Mission
- Task
- Trail
- Skill
- Interest
- User
- Guild
- Enterprise
- Location
- Season

### 15.1 目的

- 類似Quest、次のMission、実行可能なTaskを発見する。
- 必要なSkill、知識、場所、時期を理解する。
- 適切なGuildや経験者を見つける。
- 企業支援をユーザーの文脈に適合させる。
- Horizonで次の挑戦を提案する。
- 挑戦から得た経験をPassportへ接続する。

### 15.2 競争優位

Challenge Graphは、一般的なソーシャルグラフではなく、
「誰が誰を知っているか」に加えて「何に挑戦し、何を学び、何が必要か」を
表現する。十分な信頼、同意、データ品質が確立した後、Questraの
長期的な競争優位になり得る。

### 15.3 実装順序

MVP/Betaではリレーショナルデータとタグで基礎を作る。専用グラフDB、
埋め込み検索、複雑な推論は、利用価値と運用能力を検証してから導入する。

## 16. Arc Memory

Arc Memoryは、Arcがユーザーの旅路を継続的に理解するための記憶層である。
記憶は利便性のためのものであり、ユーザーを操作するためのものではない。

### 16.1 記憶の例

- Quest Memory
- Mission Memory
- Task Memory
- Trail / Reflection Memory
- Preference Memory
- Emotional Memory
- Life Event Memory
- Arc Relationship Memory
- Star Memory

### 16.2 原則

- 保存目的を明確にする。
- 重要度、関連度、新しさで取得件数を制限する。
- センシティブ情報を既定で会話コンテキストへ送らない。
- ユーザーが確認、編集、非表示、削除できる設計にする。
- 記憶の出典を追跡できるようにする。
- AI生成の推定を事実として固定しない。
- 保存期間と削除手順を定義する。

### 16.3 MVP境界

MVP/BetaではQuest、Mission、Task、Trail、Reflection、Arc Chatからの限定的な
記憶を扱う。人生全体の自動記録や外部データ統合はFutureとする。

## 17. Enterprise Platform

Enterprise Platformは企業がQuestを配る仕組みではない。企業が、
ユーザー自身のQuestを支援するためのプラットフォームである。

### 17.1 企業の4つの役割

1. **Sponsor**
   特典、報酬、割引、費用支援を提供する。
2. **Coach**
   専門知識、学習コンテンツ、助言を提供する。
3. **Partner**
   商品やサービスを通じて挑戦の実行を支援する。
4. **Official Event Host**
   公式チャレンジ、イベント、安全な参加機会を開催する。

### 17.2 表示原則

企業が前面に出るのではなく、ArcがユーザーのQuestに必要な支援として
透明に紹介する。企業名、支援内容、選定理由、対価関係、条件を表示する。
ユーザーは拒否、非表示、代替案の選択ができる。

### 17.3 企業に許されないこと

- 個人のQuestを無断で閲覧・利用する。
- Quest作成を広告導線に変える。
- Arcの人格を企業ごとに買い取る。
- 支援の条件として不必要な個人情報を要求する。
- 不透明な優先表示で推薦を歪める。

Enterprise PlatformはPhase 4以降の領域であり、MVP/Betaへ複雑な企業機能を
持ち込まない。

## 18. Quest Support Model

Quest Supportは、ユーザーの既存Questに対して、適合する支援を提示する
モデルである。

### 18.1 適合条件

- Quest DNAとの関連が説明できる。
- Missionの実行可能性を高める。
- リスクや費用を不当に増やさない。
- ユーザー設定と公開範囲に適合する。
- 同等の非スポンサー選択肢を排除しない。

### 18.2 透明性

支援表示には最低限、次を含める。

- 支援者
- 支援内容
- 対象条件
- 費用または特典
- 広告・スポンサー関係
- 推薦理由
- 非表示とフィードバック手段

### 18.3 評価

クリック率だけで評価しない。Quest前進への寄与、満足度、信頼、
キャンセル率、非表示率、苦情、安全性を含めて判断する。

## 19. Quest Marketplace

Quest Marketplaceは、Questテンプレート、専門ガイド、イベント、支援、
学習資源などを発見・取得する将来構想である。

MarketplaceはMVPに含めない。導入前に、品質審査、返金、表示透明性、
レビュー操作対策、子どもの保護、危険Questの禁止、収益分配、
知的財産、地域法令を定義する。

Marketplaceの中心は「商品を売ること」ではなく、「Questの成功可能性と
体験品質を高めること」である。

## 20. Quest Passport

Quest Passportは、ユーザーが自分の挑戦、Trail、Skill、Constellation、
証明可能な成果を持ち運ぶための将来機能である。

### 原則

- 本人が所有・管理する。
- 公開範囲を項目単位で選べる。
- 完了だけでなく継続、再挑戦、学びも表現する。
- 自己申告、AI推定、第三者証明を区別する。
- 企業や学校への共有は明示的かつ撤回可能にする。
- Passportを採用選考の強制条件にしない。

Quest PassportはPhase 5以降であり、MVPには含めない。

## 21. Quest Score

Quest Scoreは、挑戦の継続、学び、信頼性、貢献などを理解するための
将来構想である。単一の人間価値スコアにしてはならない。

### 必須ガードレール

- 一つの総合点で人を序列化しない。
- 評価軸と算出根拠を説明する。
- AI推定と検証済み事実を区別する。
- 異議申立て、訂正、再計算を可能にする。
- 企業による自動排除に使用させない。
- 公開を既定にしない。
- 文化、所得、障害、生活環境による不公平を監査する。

Quest ScoreはPhase 5以降であり、十分な倫理・法務・公平性検証なしに
実装しない。

## 22. Trust, Privacy, and Transparency

信頼は機能ではなく、全設計に適用する制約である。

### 22.1 Privacy by Design

- 目的に必要な最小データのみ収集する。
- Privateを安全な既定値とする。
- 利用目的、保存先、保存期間を説明する。
- 個人データの閲覧、エクスポート、訂正、削除を可能にする。
- RLSと所有者管理により、ユーザーごとのデータを分離する。
- 本番秘密情報をクライアントへ埋め込まない。

### 22.2 同意

同意は具体的、理解可能、目的別、撤回可能でなければならない。
利用規約への包括同意だけで、個別のQuestデータを広告、採用、保険、
信用評価などへ転用してはならない。

### 22.3 AI透明性

- AIが生成・推定した情報であることを示す。
- 推薦理由を表示できるようにする。
- スポンサー関係を明示する。
- 重要なAI判断の入力、モデル、プロンプト版、出力、採否を監査可能にする。
- 誤りを報告し、訂正できる導線を持つ。

### 22.4 セキュリティ

- 最小権限
- RLS
- 暗号化
- 秘密管理
- 監査ログ
- 脆弱性対応
- バックアップと復旧
- インシデント通知

これらをBeta開始前の必須条件として段階的に検証する。

### 22.5 データ分類と保持

データを少なくともPublic、Internal、Confidential、Sensitiveに分類する。
認証情報、秘密鍵、個別のQuest、Arc Memory、安全シグナルは必要最小限の
権限で扱い、ログ、分析、プロンプトへ無制限に複製しない。

- 保存期間は目的ごとに定義し、不要になったデータを削除または匿名化する。
- Backup、Cache、Analytics、AI Providerへの送信を含めて削除影響を設計する。
- 集計データは再識別リスクを評価し、少人数の集計を外部提供しない。
- 開発・検証環境で本番個人データを既定利用しない。

### 22.6 認証と不正利用対策

- Mobileの継続セッションとWebの再認証は、リスクに応じて分離設計できる。
- Password reset、Token失効、端末紛失、退会、アカウント復旧を設計する。
- Login試行制限は固定回数だけに依存せず、Rate limit、段階的待機、通知、
  安全な復旧を組み合わせ、正当なユーザーを永久に締め出さない。

### 22.7 Arc Memoryの目的拘束

Arc Memoryは、作成、検索、要約、AI Context投入、訂正、削除のすべてを、
ユーザーが理解できる目的別同意へ拘束する。同意状態をクライアント表示だけに依存せず、
Serverまたは権限境界で検証する。同意不明、撤回、期限切れの場合はMemoryを利用せず、
会話やQuest管理を安全に継続する。

ユーザーは、Arcが何を覚え、どの発言や記録から作られ、いつ利用され、いつ削除されるかを
確認できる。AI生成文をユーザーの事実として保存せず、Memory単位の訂正、削除、
「覚えないで」、一括停止を提供する。
- 認証・認可エラーは情報を過剰開示せず、列挙攻撃とSession fixationを防ぐ。
- XSS、CSRF、Injection、SSRF、悪意あるUpload、Dependency攻撃をThreat Modelと
  Security Testの対象にする。Flutter Webもブラウザ境界を免除されない。

## 23. Revenue Engine

Questraの収益は、挑戦を支援した価値の対価として得る。

### 23.1 収益源

- Premium Subscription
- Quest Marketplace
- Enterprise Sponsorship
- Quest Support Placement
- Corporate Dashboard
- Aggregated Market Insights
- Future API Revenue

### 23.2 優先順位

1. Premium Subscription
2. ユーザー価値が明確なMarketplace
3. 透明なEnterprise Sponsorship / Quest Support
4. 個人を識別しないAggregated Market Insights
5. 運用成熟後のDashboard / API

### 23.3 禁止する収益モデル

- ユーザー体験を毀損する広告。
- Arcの信頼を販売する広告。
- 個別の挑戦データの無断販売。
- 不安、依存、競争を意図的に高める課金。
- 基本的なデータ削除や安全機能への課金。
- スポンサーであることを隠した推薦。

MVP/Betaでは課金機能を複雑化せず、将来のFeature Flagと計測境界のみ準備する。

### 23.4 Premium境界

- FreeでもArcとの基本相談、Quest設計、最初のMission設計を利用できる。
- Premium候補は、Missionの再設計、詳細な進捗レビュー、長期記憶など「伴走の深さ」で検討する。
- Stardust、Navigator Rank、Bond、達成確率、推薦順位、安全機能を課金で優遇しない。
- 利用回数やFair Useはサーバー側の設定と監査可能な利用記録で判定し、クライアントのフラグだけで解除できない。
- MVP/Betaでは決済を導入せず、無料範囲と将来候補を検証可能な境界だけを設ける。

## 24. Growth Strategy

成長は利用時間の最大化ではなく、価値ある挑戦の循環を増やすことで実現する。

### 24.1 成長ループ

1. Arcと最初のQuestをつくる。
2. 最初のMissionを実行する。
3. Trailを残して達成感と学びを得る。
4. 必要に応じてGuildや支援へ接続する。
5. Horizonから次のQuestを発見する。
6. 信頼できるTrailやGuild体験が自然な紹介を生む。

### 24.2 避ける成長施策

- 過剰な通知
- 無限スクロールによる滞在時間稼ぎ
- フォロワー競争
- 強制的な連続記録
- 友人招待の圧力
- 非公開データを使ったターゲティング

### 24.3 初期市場

MVP/Betaでは、具体的な挑戦を持ち、Arcとの伴走価値を検証しやすい
少人数のテスターに集中する。全カテゴリを同時に最適化せず、旅行、学習、
健康、創作、仕事などから実利用データを得て改善する。

## 25. Platform Strategy

### 25.1 段階的プラットフォーム化

Questraは最初から巨大なプラットフォームを作らない。まずQuest、
Mission、Trail、Arcの単一ユーザー価値を成立させ、その後Guild、
推薦、企業支援、Marketplace、Passport、APIへ拡張する。

### 25.2 Platform Core

- Identity and consent
- Quest / Mission / Task / Trail domain
- Quest DNA
- Arc Memory
- Tagging and recommendation
- Challenge Graph foundation
- Trust and moderation
- Enterprise support boundary
- Analytics and auditability

### 25.3 開放性

将来のAPIやSDKはユーザーのデータ可搬性を高めるために設計する。
囲い込みを目的にせず、権限、目的、保存期間、取り消しを明確にする。

## 26. Success Metrics

単一のNorth StarだけでQuestraを評価しない。価値、信頼、安全、事業性を
組み合わせる。

### 26.1 MVP/Beta主要指標

- Onboarding完了率
- 初回Quest作成率
- Quest作成から最初のMission採用までの時間
- 初回Mission完了率
- 初回Trail記録率
- 7日・30日のQuest継続率
- Arc提案の採用、編集、拒否率
- 保存成功率と同期失敗率
- クラッシュフリー率
- Betaフィードバック解決時間

### 26.2 体験・信頼指標

- Arcが自分の旅路を理解していると感じる割合
- Arcへの信頼
- 推薦理由の理解度
- 通知の有用性と非表示率
- データ削除・公開範囲変更の成功率
- 不快、圧力、誤誘導の報告数
- Guildの安全性と有用性
- AI提案の不正確さ、過剰拒否、危険な見逃し
- 重大なアカウント措置の異議申立て率と覆り率

### 26.3 長期指標

- Questの完了、継続、再挑戦
- Trailから得られた学び
- Guildによる前進
- 支援がQuestへ与えた実質的効果
- Passportによる機会創出
- Premium継続率
- 企業支援の透明性評価

利用時間や通知開封率は補助指標であり、成功そのものとみなさない。
指標は年齢、言語、端末、アクセシビリティ条件などで不当な格差がないか、
収集可能かつ適法な範囲で分解して確認する。改善指標がTrust指標を悪化させる
場合、成長施策を停止して原因をレビューする。

### 26.4 Meaningful Progress North Star

主要North Starは、週に一度以上、本人が承認したQuestに対して意味のある前進を行った
ユニークユーザーを示す `Weekly Meaningful Progress Users` とする。意味のある前進には、
Mission成果の完了、親Missionを前進させるTask完了、学びや証拠を残すTrail、承認済みの
航路改善を含める。

チャット回数、滞在時間、通知開封、連続利用日数、Stardust獲得だけを意味のある前進と
みなしてはならない。Activation、D7/D30継続、Trust、Wellbeing、AI原価をGuardrailとして
同時に確認し、North Star向上のために圧力、依存、Privacy侵害を許容しない。

## 27. Roadmap

### Phase 1: MVP

目的はQuestからTrailまでの核となる循環を成立させること。

含めるもの:

- Arc Onboarding
- Quest作成
- Mission生成
- Trail記録
- Arc Chat
- Basic Guild
- Profile
- Supabase Persistence

完了条件:

- ユーザーがログインし、自分のQuest、Mission、Task、Trailを永続化できる。
- Arcが文脈に沿う基本的な伴走を提供する。
- 主要導線がクラッシュせず、RLSで所有者が分離される。

### Phase 2: Beta

目的は実ユーザーが継続利用できる品質と運用体制を作ること。

- レスポンシブ・アクセシビリティ改善
- 実機検証
- 空データ状態
- エラー・クラッシュ収集
- AI品質評価とFallback
- Feedback運用
- Privacy / Terms確認
- Supabase本番候補環境
- Beta Go / No-Go

### Phase 3: v1 Launch

目的は一般ユーザーが安心して利用できる製品を提供すること。

- Onboardingと初回Questの完成
- Retention改善
- Arc体験の成熟
- Guild安全運用
- Premiumの最小導入
- Store審査と公開運用

### Phase 4: Enterprise Platform

目的は企業をQuest支援者として安全に接続すること。

- Sponsor / Coach / Partner / Official Event Host
- 透明なQuest Support
- Corporate Dashboard
- 企業審査と監査
- 集計データのプライバシー保護

### Phase 5: Marketplace / Passport / Score

目的は挑戦資産を発見、証明、持ち運び可能にすること。

- Quest Marketplace
- Quest Passport
- Constellation証明
- Quest Scoreの限定的・説明可能な実験
- 公平性、法務、異議申立て

### Phase 6: Global Platform

目的は地域、言語、組織を越えるChallenge Infrastructureを構築すること。

- 多言語・多地域
- Quest API
- Arc SDK
- Global Quest Events
- 教育・地域・行政連携
- Challenge Graphのグローバル展開

各Phaseは、前Phaseの価値、安全、運用、信頼が検証されるまで開始しない。

### Phase Gate共通条件

次Phaseへ進む判断は、機能数やQST番号だけで行わない。少なくとも次を満たす。

- 対象Phaseの主要ユーザーフローが実環境で再現可能である。
- CriticalなSecurity、Privacy、Data loss、Safety blockerが0件である。
- 未解決HighリスクにOwner、期限、回避策がある。
- AI失敗、通信断、空状態、保存失敗でユーザーの操作が破綻しない。
- 認証が必要なrouteは直接URL、再読み込み、deep linkでも保護され、未認証ユーザーは認証フローへ戻る。
- 配布構成では、必須Backend設定の欠落を開発用ローカルデータへ黙ってFallbackせず、起動を安全に停止するか明示的なDemo Modeとして区別する。
- 主要画面が3秒ルール、1画面1主要CTA、状態完全性を満たし、実データと開発用表示を混同しない。
- スマートフォン縦画面、200%文字、日本語IME、キーボード、Screen readerの対象証跡がcandidate SHAへ結び付いている。
- RLS、認証、Backup、Rollback、監視、問い合わせ導線の証跡がある。
- Legal、Store、Accessibility、Performanceの対象Gateを通過している。
- Go / No-Goの根拠と残余リスクをRelease Reportへ残す。

## 28. Anti-Goals

Questraは次のものを目指さない。

- 高機能ToDoリスト
- 汎用AIチャットアプリ
- 成果自慢を中心にしたSNS
- 広告閲覧時間を最大化するメディア
- 人間を単一スコアで序列化する信用サービス
- 企業がユーザーへ課題を押し付ける業務プラットフォーム
- Arcとの疑似依存を収益化するサービス
- すべてを自動化し、ユーザーの判断を奪うサービス
- MVP段階で全Future機能を抱える巨大システム

機能案がAnti-Goalへ近づく場合、採用理由ではなく不採用理由を優先して検討する。

## 29. Technical Constitution

### 29.1 現時点の技術方針

- Flutter
- Supabase
- Gemini-first AI architecture for MVP/Beta
- Future provider abstraction for OpenAI or other LLMs
- Repository pattern
- Clean separation between UI, domain, data, and AI services
- Security and privacy by design
- Auditability for AI recommendations
- Scalability for future platform features

### 29.2 アーキテクチャ原則

- UIはSupabaseやLLM SDKへ直接依存しない。
- Domain modelは画面都合や特定Providerへ過度に依存しない。
- Repositoryが保存・取得境界を担う。
- AI ServiceがPrompt、Provider、Fallback、解析を担う。
- Feature Flagで未成熟機能を安全に分離する。
- Migrationは追記型かつ再現可能にする。
- RLSをクライアント実装の代替にしないが、必須防御層とする。
- 外部APIの秘密鍵をFlutterクライアントへ配置しない。

### 29.3 品質

- 重要なdomain logicには単体テストを持つ。
- 主要フローにはWidgetまたはIntegration Testを持つ。
- compact、medium、expandedの表示を検証する。
- 保存失敗、ネットワーク断、AI失敗、空状態を検証する。
- `dart analyze`、`flutter test`、Migration検証をRelease Gateにする。
- 性能Budget、画像容量、取得件数、ページングを定義する。
- AIが返す親子・依存グラフ、列挙値、件数、文字数を信頼せず検証する。
- UIの成功だけでなく、DB保存後の再取得と所有者分離を検証する。
- Test、Mock、In-memory成功をクラウド配備完了の証拠として扱わない。

### 29.4 Supabase

Beta前に実クラウドProjectを作成し、環境分離、Migration適用、Auth、RLS、
Storage、Edge Functions、Backup、監査ログを検証する。In-memory Repositoryは
UI開発とテスト用途に限定し、Beta永続化の証拠として扱わない。

### 29.5 将来拡張

Challenge Graph、Vector Search、Data Warehouseなどは、現在の価値を証明し、
データ量と運用要件が発生してから導入する。将来性を理由にMVPを複雑化しない。

### 29.6 Candidate Identity and Runtime Control

Release証拠は、Git SHA、artifact checksum、Migration head、Edge Function version、
AI model、Prompt、Schema、Feature Flag、検証環境を一つのcandidate manifestへ固定する。
別SHA、Mock、静的文字列検査、未配備コードの成功をcandidateのPassとして転用しない。

外部Providerを使う処理は、呼出し前の利用許可と予算確保、呼出し後の実使用量確定、
idempotency、timeout、停止スイッチを持つ。上限を設計文書だけに置かず、競合requestでも
超過しない権限境界で強制する。

## 30. AI Development Constitution

### 30.1 Provider Strategy

MVP/BetaはGemini-firstとする。ただしdomainとUIをGemini固有APIへ結合せず、
共通interfaceを介してOpenAIや他LLMへ切替・併用できる構造にする。

### 30.2 AIの役割

- Questの整理
- Mission候補生成
- Trail Reflection支援
- Arc Chat
- Tagging
- Recommendation
- Safety review

AIはユーザーの最終意思決定者ではない。

### 30.3 必須要件

- System promptと人格ルールをVersion管理する。
- 入力コンテキストを必要最小限に制限する。
- Provider、Model、Prompt version、Latency、結果種別を監査可能にする。
- Personal dataとセンシティブデータの送信ルールを定義する。
- Timeout、Retry、Fallback、Rate limitを持つ。
- Structured outputにはSchema validationを使う。
- 高リスク出力には安全ガードと適切な案内を持つ。
- ユーザーが生成結果を編集、拒否、再生成できる。
- Prompt injection、Data exfiltration、Unsafe completionをThreat Modelへ含める。
- 外部検索結果やユーザー生成文をSystem instructionと同じ権限で扱わない。
- Mission、評価、推薦は構造検証とDomain rule検証の双方を通す。
- AIだけで永久BAN、信用スコア、採用・保険・融資などの重大判断を確定しない。
- Provider障害時はArc人格を保った安全なFallbackまたは手動導線を提供する。

### 30.4 AI評価

正しさだけでなく、Arcらしさ、文脈適合、実行可能性、安全性、透明性、
多様性、押し付けの少なさを評価する。代表的なQuestと失敗ケースを
Evaluation Setとして保守する。

### 30.5 Codex開発

Codexは本書、下位仕様、Backlog、現在のコードを順に参照する。
仕様と実装が矛盾する場合は黙って範囲を広げず、差分を記録し、
本書のNon-Negotiable Principlesを優先する。QST完了時は実装、テスト、
レポート、Backlogを整合させる。

## 31. Company / Operating Constitution

### 31.1 意思決定

- Product、Technology、Trust/Safety、Businessの観点を分離して検討する。
- Non-Negotiable Principlesに反する売上機会を拒否する。
- 重要なデータ利用、AI方針、企業支援はDecision Recordを残す。
- 本書の変更は通常のコピー修正より重く扱い、理由と影響を記録する。

### 31.2 ユーザーとの関係

- 不具合、データ利用、AIの限界を隠さない。
- Betaであることと実験的機能を明示する。
- フィードバックへ回答し、重大問題の対応状況を共有する。
- データ削除、退会、問い合わせを意図的に難しくしない。

### 31.3 企業との関係

- 支援品質、透明性、安全性を契約条件に含める。
- Arcの独立性とユーザー優先を譲渡しない。
- 個人データへのアクセスを最小化し監査する。
- 支援の成果をクリックや売上だけで評価しない。

### 31.4 運用

- インシデント対応責任者と連絡経路を定める。
- Release GateとRollback条件を定める。
- 法務、プライバシー、セキュリティレビューを適切なPhaseで実施する。
- 小さなチームでも監査証跡と権限分離を可能な範囲で維持する。

### 31.5 Constitution Governance

本書のOwnerはQuestraのProduct責任者であり、TechnologyとTrust/Safetyの
共同レビューを受ける。改定はGit履歴だけに依存せず、次を記録する。

- 変更理由と解決する問題
- 影響する原則、Phase、データ、ユーザー
- 既存仕様と実装への移行方法
- 反対意見、代替案、残余リスク
- 承認者、発効日、次回確認時期

緊急の安全対応は先行できるが、事後レビューと恒久仕様への反映を省略しない。
本書を完成済みとして固定化せず、中心思想を守りながら証拠に基づき改定する。

### 31.6 Product Definition of Done

機能またはQSTは、コードが動くだけでは完了しない。対象に応じて次を満たす。

- ユーザー価値、対象外、失敗時の挙動が定義されている。
- Domain、UI、Data、AIの境界が既存原則と整合する。
- Security、Privacy、Safety、Accessibilityへの影響がレビューされている。
- Unit、Widget、Integration、RLS、実機の必要な検証が通る。
- Migration、Rollback、Feature Flag、運用手順が必要に応じて用意される。
- 表示文言がQuestra用語とArc Constitutionに従う。
- QST Report、Backlog、下位仕様、実装状態が一致する。

## 32. Future Ideas

以下は将来構想であり、MVPに含めない。

- Quest Passport
- Quest Score
- Quest Marketplace
- Quest API
- Arc Store
- Arc SDK
- Life Timeline
- Education Platform
- Government Collaboration
- Global Quest Events

Future Ideasは本書の原則に適合し、現在Phaseの価値と安全が証明された後に、
独立した下位仕様とQSTを作成して検討する。アイデアの存在を実装約束として
扱わない。

## 33. Final Statement

Questraは、人を急かし、比べ、消費させるためのプロダクトではない。
ユーザーが自分の挑戦を見つけ、小さな一歩を選び、その過程を大切に残し、
仲間や支援と出会い、次の可能性へ進むための基盤である。

Arcはその旅路の中心でユーザーの味方であり続ける。企業、AI、データ、
収益、成長はすべて、ユーザーのQuestを支援する範囲でのみ正当化される。

### 本書から派生すべき下位仕様書

1. `QUESTRA_MVP_SPEC.md`
2. `ARC_CONSTITUTION_SPEC.md`
3. `ARC_MEMORY_AND_PRIVACY_SPEC.md`
4. `architecture/quest-mission-task-trail.md`
5. `QUEST_DNA_SPEC.md`
6. `CHALLENGE_GRAPH_SPEC.md`
7. `GUILD_AND_MODERATION_SPEC.md`
8. `ENTERPRISE_PLATFORM_SPEC.md`
9. `QUEST_SUPPORT_TRANSPARENCY_SPEC.md`
10. `QUEST_MARKETPLACE_SPEC.md`
11. `QUEST_PASSPORT_SPEC.md`
12. `QUEST_SCORE_ETHICS_SPEC.md`
13. `AI_PROVIDER_AND_AUDIT_SPEC.md`
14. `SECURITY_PRIVACY_AND_RLS_SPEC.md`
15. `UI_UX_AND_ACCESSIBILITY_SPEC.md`
16. `ANALYTICS_AND_SUCCESS_METRICS_SPEC.md`
17. `BETA_RELEASE_AND_OPERATIONS_SPEC.md`
18. `REVENUE_AND_PREMIUM_SPEC.md`

各下位仕様は、対象Phase、非対象範囲、データ利用、リスク、Acceptance、
監査方法を明記し、本書へのリンクを持たなければならない。

### Ratification Record

- 2026-08-18: 1,000万人プロダクト監査を受け、Release Truth、First Value、Arc非強制性、Memory目的拘束、Meaningful Progress、Candidate Identity、AI予算強制を恒久原則として追加。時点評価と実装差分は `reports/qst/QUESTRA_10M_PRODUCT_AUDIT_20260818.md` と `docs/qst/QST-338-357_10M_PRODUCT_BACKLOG.md` を参照。
- 2026-08-09: v2.1としてProduct Experience Constitution、画面責務、状態完全性、認証・Demo Mode・UI/UXのBeta Gateを追加。Decision Recordは `docs/decisions/ADR-002-ui-ux-constitution.md` を参照。
- 2026-07-25: v2.0をQuestraの正式な最上位Product Constitutionとして発効。
- 適用範囲: MVP、Beta、v1、Enterprise、Marketplace、Global Platform。
- 次回必須レビュー: Beta Go / No-Go判定前、または重大な原則変更・インシデント時。

This document is the highest-level product constitution of Questra.
