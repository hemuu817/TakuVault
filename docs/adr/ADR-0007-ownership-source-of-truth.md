# ADR-0005 所有権の正本（source of truth）と混在禁止

## 決定
- Session/Asset/Tag は `user_id` が正本
- Scene は `session_id -> sessions.user_id` が正本（Sceneは user_id を持たない）
- Usage は以下が同一ユーザーであることを要求（混在禁止）
  - `asset_id -> assets.user_id`
  - `session_id/scene_id -> scenes(session_id, id) -> sessions.user_id`

## 適用
- 取得は policy_scope 起点（スコープ外は 404）
- 混在禁止は単一箇所に集約（Service に寄せる、など方式をここで確定）

## 理由
- Scene/Usage に user_id を持たせると二重管理になり整合性が崩れやすい
