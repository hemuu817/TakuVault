## 目的
MVPを締切までに「Where usedが成立」「所有権認可」「DB整合性」「アップロード安全性」を満たして出す。

## プロダクト前提
- TRPG向けクラウド素材保管庫（VTT機能は作らない）
- コア価値：Where used（素材→セッション/シーン/役割の逆引き）
- MVP：Cocofoliaのみ。room_urlは保存して参照/遷移（同期/API連携なし）

## 技術スタック（固定）
Ruby 3.x / Rails 7.x, PostgreSQL, Docker Compose, Render(Docker), ActiveStorage, Cloudflare R2

## MVP必須（固定）
- 認証：Devise
- 認可：Pundit等で方式固定（全CRUDで policy_scope/authorize、所有権徹底）
- Asset：1ファイル=1Asset（has_one_attached）
- アップロード：一括（ドラッグ&ドロップ必須 + 複数選択フォールバック）
- Usage：asset+session+scene+role に固定。scene_id NOT NULL。default_scene常設。重複不可（UNIQUE）
- 検索：display_name/original_filename + 絞り込み + ソート
- Tag：DBは多対多（UIは単数でも可）

## セキュリティ最低ライン（固定）
- room_url：http/httpsのみ、リンクは target=_blank + rel=noopener noreferrer
- host allowlist：MVPでは不採用
- アップロード制限：許可Content-Type/拡張子、サイズ上限をサーバ側で弾く（クライアント依存NG）
- ActiveStorage：認可済みAssetからのみURL生成（署名URL共有リスクはMVP許容、将来プロキシ配信検討）

## 削除整合性（固定）
- Asset削除 → Usageも削除（purge_later前提）
- Session削除 → 配下Scene/Usage削除（Assetsは残す）
- Scene削除（default以外）→ 配下Usage削除（default_sceneは削除不可）
- Tag削除 → asset_tags削除（Assetsは残す）
※DB/ARのどちらかに寄せて矛盾させない（推奨：DB CASCADE）

## DB整合性（固定）
- UNIQUE(asset_id, session_id, scene_id, role)
- scenes：scenes：UNIQUE(session_id, position)（position=1 が default_scene を担保。is_default は使わない）
- 複合FK：usages(session_id, scene_id) -> scenes(session_id, id)
- 複合FK成立条件：scenes に UNIQUE(session_id, id)

## テスト最低ライン（固定）
- モデル：添付必須、サイズ、Content-Type/拡張子、DB制約
- ポリシー：所有権
- システム：複数選択アップロード→複数Asset作成（CI安定担保）
- 手動QA：D&D動作確認（ブラウザ依存のため）

## Issue一覧
A 基盤(0001)：0006〜0008
B 認証・認可(0009)：0010〜0012
C セッション&シーン(0013)：0014〜0015, 0041
D Asset+Usage核(0017)：0018〜0024, 0042
E 検索(0027)：0028〜0030
F タグ(0031)：0032
X クラウド保管(0033)：0034〜0035
G 変換（MVP外）(0036)：0037〜0040
H Docs(0025) : 0026
※受け入れ条件の詳細は GitHub Issue本文を正本とする（このファイルに全文は複製しない）
- 正本: GitHub Issue 本文
- ローカル参照の一次情報: docs/issues/*.md
- 「Issue番号（#xx）」は再編でズレうるため、AGENTS.mdに固定レンジ（#1〜#27等）は書かない
- 対応表（INDEX）は docs/issues_snapshot.md を正本とする（GitHub #xx ↔ ローカルID/内部ID）
- Issue番号(#xx)と内部ID（例：(20) や A-1〜）がズレた場合は、docs/issues_snapshot.md を先に更新してから作業する

## Issue snapshot (Codex reading rules)
- Source of truth in this repo:
  - REQUIRED: docs/issues/*.md
  - OPTIONAL: docs/issues_snapshot.md (if present, use as a quick index only)

- At the start of every task, run these checks first (must not fail the task):
  1) `git rev-parse --abbrev-ref HEAD || true`
  2) `ls -la docs || true`
  3) `ls -la docs/issues | head || true`

- Reading strategy:
  - If `docs/issues_snapshot.md` exists:
    - `sed -n '1,80p' docs/issues_snapshot.md`
  - If it does NOT exist:
    - Proceed by reading `docs/issues/*.md` directly.

- Scope control (important):
  - Ignore mistaken issues (if present):
    - Ignore: docs/issues/0002.md - 0005.md
  - Ignore MVP-out issues:
    - Prefer: ignore issues explicitly labeled "MVP外" / "out of scope" in docs/issues_snapshot.md
    - Fallback: Ignore legacy conversion range docs/issues/0036.md - 0040.md (if still present)
  - Everything else under docs/issues is in-scope unless the user says otherwise.

- If `docs/issues/` is missing or empty:
  - Stop and report that the current checkout does not include issue snapshots.
  - Do not proceed with assumptions.


### Source of truth
- 受け入れ条件の正本: GitHub Issue 本文
- Codex が参照する一次情報: snapshot worktree 内のファイル
