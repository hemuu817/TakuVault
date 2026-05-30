# ADR-0007：所有権の正本（source of truth）と混在禁止

## Status
Accepted（MVP）

## Context
TakuVault では Session / Asset / Scene / Usage が user_id を通じて所有者に紐づく。
Scene と Usage は直接 user_id を持たない構造のため、所有権の正本をどのテーブルに置き、
どう伝播させるかを一箇所で定義しないと、認可実装が各所でバラつき整合性が崩れる。
また Usage は asset と session/scene の両系統を束ねるため、混在（別ユーザーの資源の組み合わせ）を
サーバ側で確実に排除するルールが必要になる。

## Decision

### 所有権の正本
- `Session`：`sessions.user_id` が正本
- `Asset`：`assets.user_id` が正本
- `Tag`：`tags.user_id` が正本
- `Scene`：`user_id` を持たない。`scenes.session_id → sessions.user_id` を正本とする
- `Usage`：`user_id` を持たない。以下の2系統が**同一ユーザー**であることを正本の条件とする
  - `asset_id → assets.user_id`
  - `session_id / scene_id → scenes(session_id, id) → sessions.user_id`

### 適用ルール
- 取得は必ず `policy_scope` 起点とする（スコープ外は 404）
- Usage 作成時の混在チェック（asset と session/scene が別ユーザー）は **単一箇所に集約** する
  （Service オブジェクト等に寄せる。Controller に散在させない）
- `user_id` をパラメータで受け取らない（`record.user = current_user` をサーバ側で代入する）

## Consequences
- Scene / Usage に `user_id` カラムを持たせないため二重管理を排除できる
- Usage 作成時の所有権チェックを Service に集約することで、認可漏れの発生箇所を限定できる
- policy_scope を外した `Model.find` 直打ちは認可バイパスになるため、実装レビュー時の確認項目とする

## Related
- ADR-0006：Usage割当ルール（所有権混在時の fail-closed 挙動 D5）
- ADR-0009：ADR運用ルール（policy_scope / authorize の適用方針）
- ADR-0014：許可形式・判定方式（認可済みAssetからのみURL生成）