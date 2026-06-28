# ADR-0006：Usage割当ルール（未整理一括割当 / 冪等 / 所有権整合）

## Status
Accepted（MVP）

## Context
TakuVaultのコア価値「Where used（素材→セッション/シーン/役割）」を成立させるため、Usage（asset + session + scene + role）の割当導線と、重複・不整合・所有権混在を含むエラー時挙動を固定する。  
未整理（Usage0）からの割当は頻繁に行われるため、重複で全ロールバックして作業が止まるUXを避ける必要がある。

## Decision（決定事項）

### D1. 正規導線
- Primary：**未整理（Usage0）ページで複数選択→一括割当**
- Secondary：Asset詳細（Where used）で追加（保守導線）

### D2. 一括割当の単位
- 一括割当は **同一の `session + scene + role`** を選択した複数Assetに適用して Usage を作成する  
- `role` 単体の付与は行わない（Usage作成に読み替える）

### D3. 入力項目と制約
- 入力は `session / scene / role`
- `role` は必須（推定しない。逃げ道として `other` は用意）
- `scene` 候補は選択 `session` 配下のみ提示し、不整合をUIで予防する（サーバでもDBで拒否される）
- Asset.kind は Usage.role の自動決定には使わない。
  UI上の role 候補表示補助には使ってよいが、kind-role 不一致はサーバ側で拒否しない。

### D4-P. 重複の扱い：Primary（一括割当）
- 重複判定は **(session_id, scene_id, role)** のコンテキスト単位で行う（asset単体では扱わない）
- UIは割当対象から重複を除外/明示できる（非表示 or disabled + 件数表示）
- **サーバは冪等**：
  - 既存Usageはスキップし、重複で全体を失敗させない
  - DBの `UNIQUE(asset_id, session_id, scene_id, role)` を前提とし、競合でUNIQUE違反が発生しても「重複」として吸収する（500にしない）
  - 実行結果として「作成N / 重複スキップK」をユーザーへ提示する
  - スキップされたAssetの識別情報（具体的な内容）もユーザーへ提示する（件数のみは不可）

### D4-S. 重複の扱い：Secondary（Asset詳細からの1件追加）
- 1件追加は意図的操作であるため、重複時は **422** を返す（サイレントスキップしない）
- 理由：スキップすると「いつの間にか同じUsageが存在している」状態をユーザーが認識できず、再登録作業が発生するリスクが高い

### D5. 所有権混在（fail-closed）
- asset_ids / session / scene は **policy_scope/authorize** を前提に拘束する
- `asset_ids` は `policy_scope(Asset)` と突合し、取得件数が一致しない場合は **即失敗（403/404相当）**
- エラーメッセージは情報漏えいを避ける（個別IDの露出をしない）

### D6. session–scene不整合
- UIで不整合選択を防止（scene候補をsession配下に限定）
- DB整合性は複合FKで担保（`usages(session_id, scene_id) -> scenes(session_id, id)`）

### D7. 選択状態の保持（UX）
- 一括割当の失敗（入力不備等）時でも、選択状態（asset_ids）は保持できる（再入力コストを下げる）
- 実装方式（params/hidden/Turbo等）は後続Issueで決めるが、要件として固定する

## Consequences（影響/トレードオフ）
- 一括割当は部分成功（重複スキップ）となるため、結果サマリの提示が必須になる
- スキップされたAssetの識別情報を提示するため、サマリに含める情報の設計が後続Issueで必要になる
- UIでの重複除外は補助であり、競合は起こり得るためサーバ側冪等が必須になる
- Secondary（1件追加）はPrimaryと異なり重複時に422を返すため、導線ごとに挙動が異なることを実装・テストで意識する必要がある
- 「未整理（Usage0）」の定義を固定しないと導線が割れるため、用語定義を維持する必要がある

## Definitions（用語）
- 未整理（Usage0）：Usageが **0件** のAsset（「特定セッション未割当」等の別概念はMVPでは扱わない）
- 一括割当：複数Assetに対して同一の `session + scene + role` を適用してUsageを作成すること

### D8. ルーティング（create と閲覧系の使い分け）
- Usage create（割当）は **フラット** `POST /usages` とする
  - Asset起点の割当がPrimary導線であり、session/sceneはリクエストbodyで渡す
  - `insert_all(unique_by:)` による冪等実装と相性がよく、実装が単純になる（ADR-0009 判断順位2）
- 閲覧系（Where used ツリー遅延ロード）は **ネスト** ルーティングを使用する（ADR-0010 参照）

## Examples（成功例/失敗例）
### 成功例
1. 未整理（Usage0）で複数Assetを選択し、session=A / scene=1 / role=background を指定 → Usageが作成され、Where usedに反映
2. 上記と同じ割当を再実行 → 既存Usageは重複スキップされ、処理は失敗しない（作成0/スキップN）。スキップされたAssetの識別情報がユーザーへ提示される
3. Asset詳細（Where used）で role=cutin を追加 → Usage作成が成功し一覧に追加される

### 失敗例
1. 他人のasset_idが混入したasset_idsで一括割当 → 即失敗（403/404相当、情報漏えいしない）
2. role未選択のまま一括割当 → 422相当で弾き、選択状態は保持される
3. 別sessionのsceneを指定して送信 → UI上は選べない設計。仮に送信されてもDB整合性で拒否される
4. Asset詳細（Where used）で既存と同一キーのUsageを追加しようとする → 422で返す（スキップしない）

## Related
- ADR-0001：default_scene の定義（position=1固定）
- ADR-0002：Asset.kind（content_type自動判定）
- ADR-0010：Where used ツリー遅延ロード契約（閲覧系ルーティングはネスト、create とのルーティング分離）
- Epic B：認証/認可（policy_scope/authorize）
- Epic C：Session/Scene（default_scene常設、position管理）
- Epic D：Usage作成 / Where used表示 / DB制約
- Epic E：未整理導線 / 検索・絞り込み・ソート