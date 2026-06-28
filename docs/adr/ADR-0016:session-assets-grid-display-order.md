# ADR-00XX：Session詳細「セッション素材一覧」表示仕様（用途表示順の固定化）

Status: Accepted

## Context

Session詳細は、当該セッション内で素材（Asset）が「どのシーン／どの用途」で使われているかを俯瞰する中心画面である。

既存の ADR-0008 では、Session詳細の「セッション素材一覧」について、行=Scene、列=用途（Usage.role enum）とし、用途列の表示順も enum 定義順としていた。

しかし Usage.role を拡張する場合、enum値は後方互換のため末尾追加が基本となる一方、UI上の自然な表示順は enum 定義順と一致しない。

そのため、用途列は引き続き Usage.role の許容値から生成しつつ、UI上の表示順は enum 定義順から分離し、固定表示順を正本化する。

## Decision

### D1. 用語（UI表記）

- Session詳細のグリッドは **「セッション素材一覧」** と呼ぶ。
- 列見出しは **「用途」** と表記する。
- 実装上の用途は **Usage.role** を指す。

### D2. グリッド構造

- **行=Scene（position昇順）／列=用途（Usage.role）** とする。
- default_scene は ADR-0001 に従い、position=1 として先頭行に表示する。
- 用途列は **Usage.role の許容値から生成**する。
- 用途列をビュー側にベタ書きして、Usage.role と二重管理しない。
- ただし、用途列の **表示順は enum 定義順に依存しない**。

### D3. セル内の表示（素材タイル）

- セル（scene × 用途）には、該当Usageの素材（Asset）をタイル表示する。
- タイルの最小表示は **サムネイル＋display_name** とする。

### D4. 音声素材の扱い（性能優先）

- 音声素材は **固定サムネイル画像（共通プレースホルダ）** を表示する。
- **セッション素材一覧内では音声を再生しない**。
- 音声の再生は **素材詳細（/assets/:id）** に委譲する。

### D5. 遷移（詳細表示）

- タイルクリックで **素材詳細（/assets/:id）** に遷移する。
- モーダル表示は任意だが、内容は /assets/:id と同一とし、Session詳細専用の別詳細は作らない。

### D6. 表示順の安定化（テスト揺れ防止）

- Scene：position昇順。
- 用途：固定表示順。
- 用途の固定表示順は、実装上の正本を **Usage::DISPLAY_ROLE_ORDER** とする。
- Usage::DISPLAY_ROLE_ORDER は、Usage.role の許容値をUI表示用に並べた配列とする。
- 用途の固定表示順は以下とする。

  1. background
  2. standing
  3. cutin
  4. panel
  5. bgm
  6. sound_effect
  7. other

- セル内の素材（同一 scene × role 内の複数Asset）は、以下の順序で安定化する。
  - usages.created_at 昇順
  - 同一 created_at の場合は usages.id 昇順（tie-breaker）

- 目的は「表示の決定性」と「テストの安定性」であり、display_name の変更で順序が変わらないことを優先する。

### D7. role追加時の扱い

- Usage.role を追加する場合、Usage::DISPLAY_ROLE_ORDER にも追加する。
- Usage.role の許容値と Usage::DISPLAY_ROLE_ORDER は常に整合している必要がある。
- Usage.role の許容値に存在するが Usage::DISPLAY_ROLE_ORDER に含まれないroleがある状態は、表示順の正本漏れとして扱う。
- role列の追加により横幅が増えることは許容する。
- 横幅増加への対応は、横スクロール等により画面が破綻しないことを目的とする。
- 具体的なCSS、Tailwindクラス、レスポンシブ実装は後続Issueで決める。

### D8. Asset.kind との関係

- セッション素材一覧の列は Usage.role に基づく。
- Asset.kind は用途列の生成、表示順、Usage.role の自動決定には使わない。
- kind-role 不一致を理由に、既存Usageを非表示にしない。

### D9. 旧ADRの扱い

- 本ADRは ADR-0008 を置き換える。
- 本ADRが Accepted になった場合、旧 ADR-0008 の Status は Superseded に更新し、本ADRへの参照を追記する。
- 旧 ADR-0008 の履歴は削除しない。

## Consequences

- enum定義順とUI表示順を分離できるため、Usage.role の末尾追加と自然なUI表示順を両立できる。
- 用途列の生成元は Usage.role のまま維持するため、ビュー側のベタ書き二重管理は避けられる。
- Usage::DISPLAY_ROLE_ORDER が追加されるため、Usage.role 追加時には表示順定数の更新も必要になる。
- role列が増えることで横幅は増えるが、Session詳細は一覧性を優先し、横スクロール等での対応を許容する。
- セル内素材順は既存 ADR-0008 の方針を維持するため、display_name変更による表示順の揺れは発生しない。
- 本ADRは表示仕様を扱う。Usage作成・割当・冪等性・所有権混在の扱いは ADR-0006 を正本とする。
- 本ADRは Asset.kind の分類方針を扱わない。Asset.kind の責務は別ADRを正本とする。

## Supersedes

- ADR-0008：Session詳細「セッション素材一覧」表示仕様（MVP）

## Related

- ADR-0001：default_scene（position=1固定）
- ADR-0006：Usage割当ルール（未整理一括割当 / 冪等 / 所有権整合）
- ADR-0008：Session詳細「セッション素材一覧」表示仕様（MVP）
- ADR-0009：ADR運用ルール（正本化・参照境界・改訂手順）
- ADR-0002 またはその後継ADR：Asset.kind