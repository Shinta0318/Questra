# ADR-001: Questra Master Spec v2.0 Ratification

- Status: Accepted
- Decision date: 2026-07-25
- Effective date: 2026-07-25
- Decision owner: Questra Product Owner
- Review domains: Product, Technology, Trust/Safety

## Context

Questraの開発がMVP機能からBeta品質、Quest Intelligence、将来の企業支援へ
広がり、個別QSTだけでは世界観、データ利用、AIの権限、収益方針の
判断を一貫させられないリスクが生じた。

## Decision

`docs/QUESTRA_MASTER_SPEC_V2.md`をQuestraの正式な最上位Product Constitutionとして
発効する。すべての下位仕様、QST、実装、企業提携、AI利用は本書に準拠する。

## Material additions at ratification

- 仕様優先順位、規範の強さ、変更管理
- Quest Intelligence、動的Missionグラフ、明示同意による再航路
- AI評価の説明可能性とユーザー希望期限の保護
- 段階的なTrust & Safety措置、人間レビュー、異議申立て
- 認証、データ分類、Web攻撃、AI固有攻撃の技術原則
- Phase GateとProduct Definition of Done

## Consequences

- 既存のコードや下位文書は自動的に準拠済みとみなさず、順次監査する。
- Future Ideaの記載は実装約束を意味しない。
- 原則の緩和やデータ利用目的の拡大には追加レビューが必要になる。

## Residual risks

- 下位仕様の一部は本書の章参照とPhase境界が未記載である。
- Beta Supabaseの実機証跡は、文書の承認とは別にRelease Gateで必要である。

## Next review

Beta Go / No-Go判定前、または重大なデータ・AI・安全インシデント後。
