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
- scenes：UNIQUE(session_id) WHERE is_default=true（default_scene一意）
- 複合FK：usages(session_id, scene_id) -> scenes(session_id, id)
- 複合FK成立条件：scenes に UNIQUE(session_id, id)

## テスト最低ライン（固定）
- モデル：添付必須、サイズ、Content-Type/拡張子、DB制約
- ポリシー：所有権
- システム：複数選択アップロード→複数Asset作成（CI安定担保）
- 手動QA：D&D動作確認（ブラウザ依存のため）

## Issue一覧（正本はGitHub Issues #1〜#27）
A 基盤：#1〜#3
B 認証・認可：#4〜#6
C セッション&シーン：#7〜#8
D Asset+Usage核：#9〜#16
E 検索：#17〜#19
F タグ：#20
X クラウド前提：#21〜#22
G 変換（MVP外）：#23〜#26
H Docs：#27
※受け入れ条件の詳細は GitHub Issue本文を正本とする（このファイルに全文は複製しない）

## Issue snapshot（Codex向け）

- GitHub Issueの受け入れ条件は、GitHub Actionsで `automation/issue-snapshot` ブランチにスナップショット化する。
- Codexは判断材料として、必ず以下を参照すること（GitHub Webではなく、ローカルのGit参照を使う）。

### 参照手順（checkout不要）
1) スナップショットを取得
   git fetch origin automation/issue-snapshot

2) 全体一覧
   git show origin/automation/issue-snapshot:docs/issues_snapshot.md

3) 個別Issue（例：#13）
   git show origin/automation/issue-snapshot:docs/issues/0013.md

### 推奨：worktreeで参照専用ディレクトリを作る
git fetch origin automation/issue-snapshot
git worktree add ../TakuVault-issue-snapshot origin/automation/issue-snapshot

以後、Codexは ../TakuVault-issue-snapshot を開いて `docs/issues_snapshot.md` と `docs/issues/*.md` を読む。

（後片付け）git worktree remove ../TakuVault-issue-snapshot
