## 目的

TakuVault は MVPリリース済みである。

MVPでは、Phase 0（Asset / R2永続化）と Phase 1（Session / Scene / Usage / Where used成立）を実装した。
現在は、MVPで実装した機能を前提に、Post-MVP の改善・保守・アップグレードを行っていく。

## 現在の進捗状態

プロダクト状態として、TakuVault の MVPリリースは完了済みである。

一方で、GitHub Issue単位の番号・State・本文は `automation/issue-snapshot` ブランチの
`docs/issues_snapshot.md` / `docs/issues/*.md` を参照して確認する。

snapshot が参照不能、または未更新の場合、Issue単位の状態は unknown として扱う。
ただし、snapshot の未更新や参照不能を理由に、プロダクト状態を MVP未完了へ戻して解釈しない。

以後の作業は、明示的に指定がない限り Post-MVP の改善・保守・アップグレードとして扱う。

## プロダクト前提
- TRPG向けクラウド素材保管庫（VTT機能は作らない）
- コア価値：Where used（素材→セッション/シーン/役割の逆引き）
- MVP：Cocofoliaのみ。room_urlは保存して参照/遷移（同期/API連携なし）

## 技術スタック
- Ruby 3.x
- Rails 8.1.3（`config.load_defaults 7.2` を維持）
- PostgreSQL
- Docker Compose
- Render(Docker)
- ActiveStorage
- Cloudflare R2
- Solid Queue

## MVP必須（固定）
- （共通）認証：Devise（MVPでは Recoverable を導入しない。passwords ルートは出さない）
- （共通）認可：Pundit等で方式固定（全CRUDで policy_scope/authorize、所有権徹底）
- （共通）DB優先：DB制約を正とし、モデルバリデーション“依存”で整合性を担保しない（補助としては可）
  - （重要）「(8) 所有権の強制化（全リソース）」（GitHub #12 / docs/issues/0012.md）は **単独で先に完了させるIssueではない**。
    - 理由：対象のモデル/テーブル/コントローラが未作成の段階では実装不能。
    - 扱い：**横断チェックリスト**として、各リソース実装IssueのDoDに「policy_scope起点 + authorize徹底（fail-closed）」を必ず含めて満たしていく。
    - したがって #12 は、Phase 0/1 の各Issueが進むにつれて順次“満たされていく”前提で運用する（#12単独着手で詰まらないようにする）。


- （Phase 0）Asset CRUD（ActiveStorage）
  - Asset：**1ファイル=1Asset**（has_one_attached）
  - 複数ファイル投入は「ファイル数分のAssetレコード作成」を厳守
  - アップロード方式：**サーバ経由 multipart**（ActiveStorage Direct Uploadは使わない）
  - 一覧/詳細で参照できる（URL生成は認可済みAssetからのみ）
  - 未ログインでAssetへアクセスできない（一覧/詳細/作成/削除すべて）

- （Phase 0）アップロード制限（サーバ側で拒否）
  - 許可 Content-Type / 拡張子 / サイズ上限は **サーバ側で拒否**（クライアント依存NG）

- （Phase 0）クラウド永続化（Cloudflare R2）
  - preview（Render単一環境、`RAILS_ENV=production`）でR2永続化を確認（再デプロイ後も参照できる）
  - staging/prod の環境分離・バケット分割は MVP 必須にしない（将来の別Issue/別ADRで扱う）

- （Phase 0）削除整合性
  - Asset削除後は参照不能（画面・直アクセス双方）
  - Asset削除 → Usage削除 → purge/purge_later で整合させる（詳細は「削除整合性」参照）

- （Phase 1）Where used成立（Session / Scene / Usage / Asset詳細Where used）
  - Session を作成/参照でき、room_url を保存・参照できる（http/httpsのみ）
  - Scene CRUD + position をMVPに含める
    - Session作成時に default_scene を自動作成する
    - default_scene は position=1 固定とし、削除不可にする
    - Sceneの追加・参照・更新・削除は docs/issues/0015.md（GitHub #15）の範囲で扱う
  - Usage割当ルール決定をMVPに含める
    - docs/issues/0018.md（GitHub #18）をMVP対象として扱う
    - ADR-0006 は Phase 1 の Usage割当ルールの正本として扱う
    - ADR-0006のPrimary導線（未整理（Usage0）ページで複数選択→一括割当）をMVPのUsage作成導線に含める
    - Asset詳細からのUsage追加/削除は Secondary / 保守導線として扱う
  - Usage を作成できる
    - 複数Assetに対し、同一の session + scene + role を指定してUsageを作成できる
    - 重複は ADR-0006 に従い、既存Usageをスキップする冪等挙動とする
    - UNIQUE(asset_id, session_id, scene_id, role) を前提にする
  - Asset詳細に Where used（Usage一覧）が表示される（includes等でN+1回避）
  - 所有権不一致の asset / session / scene への紐付けは fail-closed（403/404相当）
  - Session詳細に「セッション素材一覧」が表示され（行=Scene／列=用途）、タイルから素材詳細へ遷移できる（ADR-0008準拠）

- （Deferred：MVPリリース要件に含めない）
  - 検索/絞り込み/ソート
  - タグ機能
  - 未整理（Usage0）ビューのうち、検索・絞り込み・素材一覧拡張としてのリッチ版
    - ただし、ADR-0006のPrimary導線に必要な「未整理（Usage0）ページで複数選択→一括割当」はPhase 1に含める
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

- spec は実装の一部（全網羅義務なし。認可/所有権 + 主要導線を優先）。CI green を維持する。
  - RSpec の実行は bin/rspec を使用する
- 手動QA（最低ライン）：
  - ログイン → アップロード → 一覧/詳細参照 → 削除 → 再参照不可
  - preview（Render単一環境）で R2 永続化（再デプロイ後も参照できる）
  - 認可境界：他人のURL直打ちが通らない（一覧/詳細/削除）

## Issue一覧
A 基盤(0001)：0006〜0008  
B 認証・認可(0009)：0010〜0012  
C セッション&シーン(0013)：0014〜0015, 0041  
D Asset+Usage核(0017)：0018〜0024, 0042, 0136 
E 検索(0027)：0028〜0030  
F タグ(0031)：0032, 0065  
X クラウド保管(0033)：0034〜0035  
G 変換（MVP外）(0036)：0037〜0040  
H Docs(0025)：0026  
Z その他（MVP外候補）：0061, 0068〜0071  

## 作業順序（固定：この順で進める）
※「Issue番号（#xx）」はズレうるため、**Local（docs/issues/xxxx.md）を主キー**として参照する。GitHub # は issues_snapshot の対応表に従う。

### Phase 0（最優先：AssetがR2に永続保存できるまで）
1. docs/issues/0019.md（GitHub #19）(14) Asset CRUD(ActiveStorage)
2. docs/issues/0035.md（GitHub #35）(27) 容量/ファイル上限方針（#19に密結合。サーバ側で拒否）
3. docs/issues/0024.md（GitHub #24）(19) Asset削除整合性
4. docs/issues/0034.md（GitHub #34）(26) 本番ストレージ構成（ActiveStorage + R2、preview=production単一環境で永続化確認）
- 余力枠：docs/issues/0020.md（GitHub #20）(15) Asset kind（Phase 0 DoD 必須ではない）

### Phase 1（次点：Where used成立）
5. docs/issues/0014.md（GitHub #14）(10) Session CRUD（room_url保存/参照、http/httpsのみ）
6. docs/issues/0015.md（GitHub #15）(11) Scene CRUD+position
7. docs/issues/0018.md（GitHub #18）(13) Usage割当ルール決定(spike)
   - ADR-0006をPhase 1のUsage割当ルールの正本として確認する
   - ADR-0006のPrimary導線（未整理（Usage0）ページで複数選択→一括割当）をMVPに戻す
   - ADR-0006の意味変更が必要な場合は、AGENTS.md修正後に別途ADR改訂として扱う
8. docs/issues/0021.md（GitHub #21）(16) Usage作成
   - ADR-0006に従い、Primary=未整理（Usage0）ページで複数選択→一括割当、Secondary=Asset詳細からの追加/削除として実装する
   - Usage作成時は asset / session / scene の所有権混在を fail-closed で拒否する
9. docs/issues/0022.md（GitHub #22）(17) Asset詳細Where used（Usage一覧表示）
10. docs/issues/0136.md（GitHub #136）Session詳細「セッション素材一覧」表示（ADR-0008準拠）
11. docs/issues/0141.md（GitHub #141）Tailwind CSS導入・ビルド基盤整備
    - 最初のフロントエンド実装Issue。Render(Docker)構成のため、Dockerfile（assets:precompile）経由で production相当でも Tailwind build が成立することをDoDに含める
12. docs/issues/0142.md（GitHub #142）既存ERB画面のTailwind retrofit
    - #11（Tailwind導入）完了後に着手。既存機能・認可境界・DB/routes/controller/model/policy は変更しない

### Deferred（MVPリリース要件に含めない）
- 検索/絞り込み/ソート：docs/issues/0027.md〜0030.md（GitHub #27〜#30）
- タグ：docs/issues/0031.md〜0032.md（GitHub #31〜#32）ほか
- 未整理（Usage0）ビューのうち、検索・絞り込み・素材一覧拡張としてのリッチ版：docs/issues/0030.md（GitHub #30）
  - ただし、ADR-0006のPrimary導線に必要な最小の未整理（Usage0）選択画面と一括割当UIはPhase 1に含める
- 変換：docs/issues/0036.md〜0040.md（GitHub #36〜#40）

※受け入れ条件の詳細は GitHub Issue本文を正本とする（このファイルに全文は複製しない）
- 正本: GitHub Issue 本文（AC/DoD/テスト観点）
- ローカル参照の一次情報: docs/issues/*.md
- 「Issue番号（#xx）」は再編でズレうるため、AGENTS.mdに固定レンジ（#1〜#27等）は書かない
- 対応表（INDEX）は docs/issues_snapshot.md を正本とする（GitHub #xx ↔ ローカルID/内部ID）
- Issue番号(#xx)と内部ID（例：(20) や Epic内番号）がズレた場合は、docs/issues_snapshot.md を先に更新してから作業する

### Phase運用（MVP計画の更新点）
- Phase 0（最優先）：A/B/D/X を中心に「R2永続化 + Asset CRUD + 制限 + 削除整合性」を成立させる
- Phase 1（次点）：C と D（Usage/Where used）で、docs/issues/0014.md → 0015.md → 0018.md → 0021.md → 0022.md → 0136.md の順にWhere used とセッション素材一覧を成立させ、最後に Tailwind CSS導入 → retrofit でUIを整える
- Deferred：E/F/G/Z はMVPリリース要件に含めない（明示指示がある場合のみ着手）

## Issue snapshot（Codex参照ルール）

- Issue snapshot の正本は、main ではなく `automation/issue-snapshot` ブランチにある。
  - 対応表: `docs/issues_snapshot.md`
  - Issue本文: `docs/issues/*.md`

- Issue番号・State・UpdatedAt・Issue本文を確認する場合は、必ず `automation/issue-snapshot` ブランチの snapshot を参照する。
  - main 上に同名ファイルが存在していても、古い可能性があるため正本として扱わない。
  - `automation/issue-snapshot` ブランチの `docs/issues_snapshot.md` と `docs/issues/*.md` を読み取れない場合は、推測で進めず、参照不能として報告する。

- 実装コード・README・ADR・AGENTS.md は、main または現在の作業ブランチを正本として扱う。
  - `automation/issue-snapshot` ブランチ上の `AGENTS.md` / `README.md` / `docs/adr/*` は参照正本にしない。
  - `automation/issue-snapshot` ブランチは Issue snapshot の読み取り専用キャッシュとして扱う。

- タスク開始時は、まず以下を確認する。
  1. 現在の作業ブランチ
  2. `automation/issue-snapshot` ブランチの `docs/issues_snapshot.md`
  3. 対象Issueに対応する `automation/issue-snapshot` ブランチの `docs/issues/*.md`

- 依存関係ゲート:
  - 対象Issueが、未作成のモデル / テーブル / コントローラを前提にしている場合、そのIssue内で前提を勝手に作らない。
  - 代わりに "BLOCKED by missing prerequisites" と報告し、`automation/issue-snapshot` の `docs/issues_snapshot.md` / `docs/issues/*.md` に基づいて依存Issueへ誘導する。
  - 例:
    - `docs/issues/0021.md`（GitHub #21 Usage作成）は Session / Scene が前提。
    - `sessions` / `scenes` が未存在なら、`docs/issues/0014.md`（GitHub #14）→ `docs/issues/0015.md`（GitHub #15）を先に確認する。

- スコープ制御:
  - MVP範囲は、この `AGENTS.md` の Phase 0 / Phase 1 / Deferred を正本とする。
  - README / ADR / Issue snapshot により豊富な将来構想が書かれていても、現在の Phase 定義に明示されていない機能は勝手に実装しない。
  - E / F / G / Z は、明示指示がない限り Deferred として扱う。
  - 検索 / 絞り込み / タグは、明示的にPhase 1へ戻されない限り Deferred として扱う。
  - `automation/issue-snapshot` 側の Issue本文に古いMVP範囲が残っている場合でも、MVPスコープ判断はこの `AGENTS.md` を優先する。

- `automation/issue-snapshot` ブランチの snapshot を参照できない場合:
  - 現在のcheckoutにある古い snapshot で代用しない。
  - Issue番号・State・本文に関する判断を unknown として扱う。
  - 必要な情報が参照不能であることを報告する。

### Source of truth
- MVPスコープの正本: 本AGENTS.md（Phase 0/Phase 1/Deferred）
- 受け入れ条件の正本: GitHub Issue 本文
- 対応表（INDEX）の正本: `automation/issue-snapshot` ブランチの `docs/issues_snapshot.md`
- プロダクト状態の正本: 本AGENTS.md（MVPリリース済み / 現在はPost-MVP）
- Issue単位のState/番号/本文の正本: `automation/issue-snapshot` ブランチの `docs/issues_snapshot.md`
- Issue単位のDone判定: `docs/issues_snapshot.md` の State=CLOSED
- snapshot が参照不能または未更新の場合、Issue単位の状態は unknown として扱う。
  ただし、snapshot の状態を根拠にプロダクト状態を MVP未完了へ戻して解釈しない。
- 運用: `automation/issue-snapshot` ブランチの `docs/issues_snapshot.md` は毎日最新化する。最新化されていない場合は unknown 扱いとする（推測で前提変更しない）。
- Issue を CLOSE してよい条件: main に反映済み（マージ済み）＋最低限の手動確認が通った場合のみ。


#### Done 判定ルール（軽量運用）
- Issue を CLOSE してよい条件は「main に反映済み（マージ済み）＋最低限の手動確認が通った」のみ。
- OPEN は未完了と断定せず、unknown / in progress / blocked を内包する扱いとする（追加ログは要求しない）。


