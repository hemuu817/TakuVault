# ADR-0007：Where used ツリー遅延ロード契約（Session/Scene/Usage）

Status: Proposed

## Context
統合画面（#23）と絞り込み（#29）は、Where used ツリーの遅延ロードに関する共通契約（入力/出力/認可/再取得/空状態）を共有する。
この契約がIssue本文に重複すると更新漏れが起きやすく、所有権認可・漏えい防止（fail-closed）に直結するためリスクが高い。
よって、遅延ロード契約をADRとして正本化し、IssueはADR参照に寄せる。

## Decision
### 0) 運用（ADR-0005準拠：Accepted化の条件）
- 本ADRは Proposed の間は参照してよいが、**本ADRを前提とする実装（#23/#29）は開始しない**。
- 本ADRを Accepted にする条件（全部満たすこと）：
  - [ ] 遅延ロードの出力形式を **HTML partial** に固定する（本ADRのまま）ことに合意している
  - [ ] エンドポイント（path）と partial名（view）を固定している（2)〜3)に記載）
  - [ ] 認可適用方針（policy_scope + authorize の適用箇所）を固定している（6)に記載）
  - [ ] #23/#29 から共通契約の重複記載を削除し、`Relates to: ADR-0007` に置換するPRを用意している（同一PRでよい）
- Accepted 以降、仕様変更（意味が変わる変更）は新ADRでSuperseded運用とする（ADR-0005）。

### 1) 取得対象と主語
- 遅延ロードの取得単位は **Scene配下のUsage一覧** とする。
- ツリーの葉は **Usage（asset + session + scene + role）** とする。
- 同一Assetの使い回しによる **Usageの重複表示は許容**する（distinctしない）。

### 2) 遅延ロードの入力（Request）
- 必須：
  - `session_id`
  - `scene_id`
- 任意：
  - `role`（Usage.role の許容値のみ）
- `kind` は **MVPでは遅延ロード入力に含めない**。
  - kind絞り込みは表示側（#29）で行うため、遅延ロード出力には **asset.kindが判別できる情報** を必ず含める（DOM属性または表示データに含める）。

### 3) 遅延ロードの出力（Response）
- 返却内容は「そのScene配下のUsage一覧」を **roleでグルーピング可能な形**で返す。
- 形式は **HTML partial** に固定する（MVP）。
  - 推奨：Turbo Frame 等で Scene 展開領域を差し替える。
- Partial I/F（固定）：
  - partial: `scenes/_usages.html.erb`（仮。Accepted化前に名称を確定）
  - locals: `usages_by_role:`（role => [Usage] の形。role順は固定順で並ぶ）
- role表示順は **enum順など固定順** とする。
- Usageは **重複排除しない**。
- N+1回避のため、Usage表示に必要な関連は必要範囲で事前読み込みする。
  - ActiveStorageを含む場合、`with_attached_file` 等を用い、attachment参照でN+1を発生させない。

### 4) 空状態（Empty state）
- role指定あり/なしに関わらず、当該Scene配下にUsageが存在しない場合、partialは **空状態を表現するHTML** を返す（200）。
- Session/Sceneの骨格表示（空ノード保持）はUI側（#23の骨格）で担保し、遅延ロードは **「中身が空」を返せる**ことを契約とする。
- Role見出しの扱いは **「要素があるroleのみ表示」** に固定する（空のrole見出しは出さない）。

### 5) role変更時の挙動（再取得ルール）
- roleが変更された場合、**展開済みSceneは再取得**する（MVP最小で安全）。
- 未展開Sceneは、展開されたタイミングでその時点のrole条件を付けて取得される。

### 6) 認可境界（fail-closed固定）
- 取得起点は必ず `policy_scope` とする。
- 取得した親資源は `authorize` を適用する（方式固定）：
  - `session = policy_scope(Session).find(session_id); authorize(session, :show?)`
  - `scene = policy_scope(Scene).where(session_id: session.id).find(scene_id); authorize(scene, :show?)`
- 子資源（Usage）は `policy_scope(Usage)` で絞り込む：
  - `usages = policy_scope(Usage).where(session_id: session.id, scene_id: scene.id)`
- スコープ外は **404** 寄せを既定とする（全体方針が変わる場合は本ADRをSupersededして統一）。

### 7) 異常系（入力不正）
- `role` が許容値外の場合は **400**（Bad Request）とする（曖昧な挙動にしない）。

### 8) エンドポイント（ルーティング）方針
- ルーティングは **ネスト**で表現し、親資源でfail-closedを担保できる形にする。
  - 例：`GET /sessions/:session_id/scenes/:scene_id/usages`（queryで `role` 任意）
- controller/action 名は実装時に確定し、本ADRの Decision へ追記して Accepted 化する。

## Consequences
- 遅延ロード契約がADR正本となるため、Issue本文の重複が減り、変更点の参照先が一意になる。
- HTML partial固定によりMVPは実装が単純になる一方、JSON/API化には将来契約変更（新ADR）が必要になる。
- `role` 不正を400に固定することで、クライアントのバグが早期に顕在化する。

## Related
- Issue: #23（素材一覧・ツリー基盤）
- Issue: #29（絞り込み：kind/role/session）
- ADR-0005：ADR運用ルール（正本化・参照境界・改訂手順）
- ADR-0006：Usage割当ルール
- ADR-0001：default_scene
- ADR-0002：Asset.kind
