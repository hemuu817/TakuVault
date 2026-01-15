# ADR-0009：ADR運用ルール（正本化・参照境界・改訂手順）

Status: Proposed

## Context
TakuVaultはMVP締切までに「Where used成立」「所有権認可」「DB整合性」「アップロード安全性」を満たす必要がある。
決定事項がIssue本文・メモ・口頭に分散すると、矛盾と参照コストが増えて実装判断が遅くなる。
決定事項の参照先をADRに一元化し、IssueはADR参照に徹する運用を定義する。

## Decision
### 1) 正本（Single Source of Truth）
- ADRは設計上の決定事項の唯一の参照先（正本）とする。
- Issue本文には「決定（Decision）」を複製しない。Issueは以下に限定する：
  - 目的（Why）
  - 受入条件（AC）/完了条件（DoD）
  - 実装タスク（Tasks）
  - 関連リンク（Relates to：ADR-xxxx）
- **境界定義**：
  - 「ルール/制約/方式/方針」＝ ADRに書く（例：NOT NULL/UNIQUE/FK、認可方式、default_scene定義）
  - 「そのADRに沿った作業内容」＝ Issueに書く（例：実装手順、UI差分、テスト観点、作業分割）

### 2) 1テーマ1ADR
- 1つのADRは1つの論点（テーマ）に限定する。
- 複数の論点が絡む場合は、基盤となる論点から順にADRを分割する。

### 3) 判断の優先順位（迷ったとき）
- 迷った場合は次の順で判断する：
  1. MVPの不変条件（Fixed）
  2. 運用の単純さ（実装/テスト/保守の単純化）
  3. 将来の拡張余地（後方互換・置換容易性）

### 4) ステータスと改訂（履歴を壊さない）
- Proposed：提案中。Issueから参照してよいが、Accepted前提の実装を開始しない。
- Accepted：採用済み。以後の実装はこれに従う。
- Superseded：置換済み。内容は原則改変せず、新ADRへの参照を追記して履歴を残す。
- **改訂ルール**：
  - 意味が変わる変更（決定の変更/撤回/置換）は、新ADRを作成し、旧ADRをSupersededにする。
  - 誤字脱字や明確化（意味が変わらない）は、既存ADRを直接修正してよい。

### 5) 参照の作法（リンクの一貫性）
- Issueは必ず `Relates to: ADR-xxxx` を記載する。
- ADRのRelatedは、Issue番号に依存せず、必要に応じて `docs/issues/INDEX.md`（対応表）を参照する。
  - ※Issue番号と(A-1〜H-27)がズレる問題を回避するため。

### 6) 配置・フォーマット
- ADRは `docs/adr/ADR-xxxx.md` に配置する。
- 出力は Markdown。
- ADRテンプレは必ず以下を含む：
  - ADR-xxxx：タイトル
  - Status
  - Context（1〜5行）
  - Decision（箇条書き、曖昧語禁止）
  - Consequences
  - Related

## Consequences
- Issue本文の記述量は減るが、ADRを読めば判断根拠が一意に追える。
- ADR更新をサボると「実装と正本が乖離」するため、更新フローを徹底する必要がある。
- Supersededを導入することで履歴が残る一方、ADR本数は増える。

## Related
- ADR-0001：default_scene（position=1固定、is_default不使用、削除不可）
- ADR-0002：Asset.kind（content_type自動判定、手動変更なし、enum値固定）
- ADR-0004：schema_format（structure.sql）
- ADR-0006：Usage割当ルール（未整理一括付与、重複スキップ、混在fail-closed）
- （推奨）docs/issues/INDEX.md：Issue番号と(A-1〜H-27)の対応表
