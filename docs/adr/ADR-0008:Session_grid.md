# ADR-0008：Session詳細「セッション素材一覧」表示仕様（MVP）

Status: Accepted（MVP）

## Context
Session詳細は、当該セッション内で素材（Asset）が「どのシーン／どの用途」で使われているかを俯瞰する中心画面になる。
一方で、ここに割当操作や再生プレビューを持ち込むと実装・性能・テストの負荷が増え、MVPの安定稼働を阻害する。
よって、MVPのSession詳細は「表示と遷移」を正とし、表示仕様を固定する。

## Decision（決定事項）

### D1. 用語（UI表記）
- Session詳細のグリッドは **「セッション素材一覧」** と呼ぶ（「素材一覧」と衝突させない）
- 列見出しは **「用途」** と表記する（実装上は Usage.role）

### D2. グリッド構造
- **行=Scene（position昇順）／列=用途（Usage.role enum）**
- default_scene は ADR-0001 に従い position=1 として先頭行に表示する
- 用途列は enum 定義から生成し、UI側のベタ書き二重管理を避ける

### D3. セル内の表示（素材タイル）
- セル（scene × 用途）には、該当Usageの素材（Asset）をタイル表示する
- タイルの最小表示は **サムネイル＋display_name** とする

### D4. 音声素材の扱い（性能優先）
- 音声素材は **固定サムネイル画像（共通プレースホルダ）** を表示する
- **セッション素材一覧内では音声を再生しない**
- 音声の再生は **素材詳細（/assets/:id）** に委譲する

### D5. 遷移（詳細表示）
- タイルクリックで **素材詳細（/assets/:id）** に遷移する
- モーダル表示は任意だが、内容は /assets/:id と同一とし、Session詳細専用の別詳細は作らない

### D6. 表示順の安定化（テスト揺れ防止）
- Scene：position昇順
- 用途：enum定義順
- セル内の素材（同一 scene × role 内の複数Asset）は、以下の順序で安定化する：
  - **usages.created_at 昇順**
  - **同一created_atの場合は usages.id 昇順（tie-breaker）**
- 目的は「表示の決定性」と「テストの安定性」であり、名称変更（display_name変更）で順序が変わらないことを優先する。

## Consequences（影響/トレードオフ）
- Session詳細は「表示＋遷移」に絞るため、割当操作は別導線（未整理/素材詳細）に依存する
- 音声再生を排除することで、初期性能と実装難易度を下げられる
- 表示順を固定することで、System spec が安定する
- display_name昇順ではないため、セル内で「名前順に探す」用途には最適化されない（MVPでは許容）

## Related
- ADR-0001：default_scene（position=1固定）
- ADR-0006：Usage割当ルール（Primary=未整理、Secondary=素材詳細）
- docs/issues/0136.md（GitHub #136）：Session詳細「セッション素材一覧」実装