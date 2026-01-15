## 目的
MVPリリース条件を **Phase 0 完了 + Phase 1（最小Where used）完了** に再定義する。

- Phase 0（最優先）：「アップロードした素材をCloudflare R2へ永続保存できるアプリとして“動く”」を成立させる
- Phase 1（次点）：「Where used への最小導線」を成立させる（Asset詳細からUsage作成＋Where used表示）
- Phase 0のみ完了は “動作確認段階” とし、MVPリリースとは呼ばない（スコープ誤読防止）

## プロダクト前提
- TRPG向けクラウド素材保管庫（VTT機能は作らない）
- コア価値：Where used（素材→セッション/シーン/役割の逆引き）
- MVP：Cocofoliaのみ。room_urlは保存して参照/遷移（同期/API連携なし）

## 技術スタック（固定）
Ruby 3.x / Rails 7.x, PostgreSQL, Docker Compose, Render(Docker), ActiveStorage, Cloudflare R2

## MVP必須（固定）
- （共通）認証：Devise（パスワードリセットを含む）
- （共通）認可：Pundit等で方式固定（全CRUDで policy_scope/authorize、所有権徹底）
- （共通）DB優先：DB制約を正とし、モデルバリデーション“依存”で整合性を担保しない（補助としては可）

- （Phase 0）Asset CRUD（ActiveStorage）
  - Asset：**1ファイル=1Asset**（has_one_attached）
  - 複数ファイル投入は「ファイル数分のAssetレコード作成」を厳守
  - アップロード方式：**サーバ経由 multipart**（ActiveStorage Direct Uploadは使わない）
  - 一覧/詳細で参照できる（URL生成は認可済みAssetからのみ）
  - 未ログインでAssetへアクセスできない（一覧/詳細/作成/削除すべて）

- （Phase 0）アップロード制限（サーバ側で拒否）
  - 許可 Content-Type / 拡張子 / サイズ上限は **サーバ側で拒否**（クライアント依存NG）

- （Phase 0）クラウド永続化（Cloudflare R2）
  - staging相当でR2永続化を確認（再デプロイ後も参照できる）
  - バケット分割（stg/prod混入なし）等の運用要件は Issue/ADR を正本とする

- （Phase 0）削除整合性
  - Asset削除後は参照不能（画面・直アクセス双方）
  - Asset削除 → Usage削除 → purge/purge_later で整合させる（詳細は「削除整合性」参照）

- （Phase 1）最小Where used（導線確保）
  - Session を作成/参照でき、room_url を保存・参照できる（http/httpsのみ）
  - Session作成時に default_scene が自動作成される（position=1固定・削除不可）
  - Asset詳細から Usage を **1件** 作成できる（session + default_scene + role）
  - Asset詳細に Where used（Usage一覧）が表示される（includes等でN+1回避）
  - 所有権不一致の session/scene への紐付けは fail-closed（403/404相当）

- （Deferred：MVPリリース要件に含めない）
  - 検索/絞り込み/ソート
  - タグ機能
  - 未整理（Usage0）専用ビュー、未整理導線、素材一括割当のUI
  - 変換（方式検証/ジョブ/進捗/自動登録/割当導線）
  - 素材詳細/素材アップロードのモーダル化
  - フッター＋静的ページ群
  - Demo用seed & 初期データ（あれば良いが、Phase 0/1 のDoDを満たすための必須条件ではない）

※注意：README/ADRにDeferred機能の記述が残っていても、実装スコープは本AGENTSのPhase定義を優先する（差し戻し/誤実装防止）。

## セキュリティ最低ライン（固定）
- room_url：http/httpsのみ、リンクは target=_blank + rel=noopener noreferrer
- host allowlist：MVPでは不採用
- アップロード制限：許可Content-Type/拡張子、サイズ上限をサーバ側で弾く（クライアント依存NG）
- ActiveStorage：認可済みAssetからのみURL生成（署名URL共有リスクはMVP許容、将来プロキシ配信検討）

## 削除整合性（固定）
- Asset削除 → Usageも削除 → ActiveStorageを削除
  - 原則：purge_later（ジョブでの後処理）
  - ただしジョブ基盤/workerが未整備・停止している環境では、暫定で同期 purge に切り替えて成立させる（後日 purge_later に戻す）
- Session削除 → 配下Scene/Usage削除（Assetsは残す）
- Scene削除（default以外）→ 配下Usage削除（default_sceneは削除不可）
- Tag削除 → asset_tags削除（Assetsは残す）
※DB/ARのどちらかに寄せて矛盾させない（推奨：DB CASCADE）

## DB整合性（固定）
- UNIQUE(asset_id, session_id, scene_id, role)
- scenes：UNIQUE(session_id, position)（position=1 が default_scene を担保。is_default は使わない）
- 複合FK：usages(session_id, scene_id) -> scenes(session_id, id)
- 複合FK成立条件：scenes に UNIQUE(session_id, id)

## テスト最低ライン（固定）
- テスト基盤：RSpec（先にセットアップしてから実装に入る）
- モデル：添付必須、サイズ、Content-Type/拡張子、DB制約
- ポリシー：所有権（他人のAsset/Session/Usageにアクセスできない）
- システム：複数ファイル選択アップロード → 複数Asset作成（CI安定担保）
- 手動QA：
  - アップロード → 一覧/詳細参照 → 削除 → 再参照不可
  - staging相当でR2永続化（再デプロイ後も参照できる）

## Issue一覧
A 基盤(0001)：0006〜0008, 0061  
B 認証・認可(0009)：0010〜0012, 0071  
C セッション&シーン(0013)：0014〜0015, 0041  
D Asset+Usage核(0017)：0018〜0024, 0042  
E 検索(0027)：0028〜0030  
F タグ(0031)：0032, 0065  
X クラウド保管(0033)：0034〜0035  
G 変換（MVP外）(0036)：0037〜0040  
H Docs(0025)：0026  
Z その他（MVP外候補）：0068〜0070  

※受け入れ条件の詳細は GitHub Issue本文を正本とする（このファイルに全文は複製しない）
- 正本: GitHub Issue 本文（AC/DoD/テスト観点）
- ローカル参照の一次情報: docs/issues/*.md
- 「Issue番号（#xx）」は再編でズレうるため、AGENTS.mdに固定レンジ（#1〜#27等）は書かない
- 対応表（INDEX）は docs/issues_snapshot.md を正本とする（GitHub #xx ↔ ローカルID/内部ID）
- Issue番号(#xx)と内部ID（例：(20) や Epic内番号）がズレた場合は、docs/issues_snapshot.md を先に更新してから作業する

### Phase運用（MVP計画の更新点）
- Phase 0（最優先）：A/B/D/X を中心に「R2永続化 + Asset CRUD + 制限 + 削除整合性」を成立させる
- Phase 1（次点）：C と D（Usage/Where used）で「最小Where used」を成立させる
- Deferred：E/F/G/Z はMVPリリース要件に含めない（明示指示がある場合のみ着手）

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
    - `tail -n 80 docs/issues_snapshot.md`
  - If it does NOT exist:
    - Proceed by reading `docs/issues/*.md` directly.

- Scope control (important):
  - Ignore mistaken issues (if present):
    - Ignore: docs/issues/0002.md - 0005.md
  - MVP in-scope is limited to Phase 0/Phase 1 as defined in this AGENTS.md:
    - Treat E/F/G/Z as out-of-scope by default (unless explicitly instructed).
    - If README/ADR contains richer flows (e.g., 未整理（Usage0）ページ、一括割当、検索/タグ等), treat them as Deferred unless the user explicitly pulls them into scope.
  - Prefer: ignore issues explicitly labeled "MVP外" / "out of scope" in docs/issues_snapshot.md
  - Fallback: Ignore legacy conversion range docs/issues/0036.md - 0040.md (if still present)

- If `docs/issues/` is missing or empty:
  - Stop and report that the current checkout does not include issue snapshots.
  - Do not proceed with assumptions.


### Source of truth
- MVPスコープの正本: 本AGENTS.md（Phase 0/Phase 1/Deferred）
- 受け入れ条件の正本: GitHub Issue 本文
- Codex が参照する一次情報: snapshot worktree 内のファイル
