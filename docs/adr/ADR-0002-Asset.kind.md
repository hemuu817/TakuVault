# ADR-0002：Asset.kind（content_type 自動判定・手動変更なし）

## Status
superseded

## Context
TakuVaultでは Asset 一覧の絞り込み、未整理導線、検索（Epic E）で「素材種別」を安定して扱う必要がある。
MVPではユーザーの手動選択や推定ロジックを入れず、添付ファイルから機械的に分類して `assets.kind` に永続化する。

## Decision

### D1. kind はDBに永続化する（enum/int）
- `assets.kind` は **enum（int） / NOT NULL / default: other** とする
- kind はMVPの分類軸として扱い、検索・絞り込みのキーにする

### D2. enum の数値割当（固定）
> **既存の整数値は将来変更しない**。kind追加は末尾に追加する（別ADR/Issueで実施）。
- `other: 0`
- `image: 1`
- `audio: 2`
- `video: 3`

### D3. kind 値（MVP固定）
- `image`, `audio`, `video`, `other`

### D4. 判定ルール（MVP固定）
- `image/*` → `image`
- `audio/*` → `audio`
- `video/*` → `video`
- 上記以外 → `other`

### D5. content_type の信頼境界（固定）
- 判定の入力は **ActiveStorage Blob が保持する `content_type`** を唯一の根拠とする
  - リクエストパラメータ由来の `kind` / `content_type` は信頼しない
- `content_type` が不明/曖昧（例：`application/octet-stream`、空）な場合は **`other`** に分類する（MVPでは許容）

### D6. 手動変更はMVP外
- kind の手動編集UI、手動上書きAPIは提供しない
- kind はサーバ側で自動決定され、ユーザー入力で改ざんできない

### D7. 添付差し替え（MVP：不可）
- MVPでは **添付差し替えをサポートしない**
  - updateでファイルを差し替える導線（UI/ルート/params）を提供しない
  - ファイルを変更したい場合は **新規Assetとして作成**する

### D8. 依存関係（順序の注意）
- アップロード安全性（許可Content-Type/拡張子/サイズ上限）は別仕様（Epic D/X）で担保する
  - kindは「分類」であり「拒否」の責務を持たない
  - ただし実装順としては、許可/拒否の導入と近いタイミングで適用するのが望ましい（挙動の一時的ズレを避ける）

### D9. 導入時バックフィル（将来の保守ガード）
- 既存Assetが存在する状態で `kind NOT NULL` を導入する場合、移行時に `other` で埋める、または添付から再計算して埋める（どちらかを実装Issueで選択する）

## Consequences
- 一覧/未整理/検索の安定性が上がる一方、曖昧MIMEは `other` に落ちる（MVPとして許容）
- kind追加は将来発生し得るが、整数値の互換性維持が必須になる（末尾追加のみ）

## Related
- Epic D：Asset CRUD / アップロード安全性
- Epic E：検索・絞り込み（kindフィルタ）
- ADR-0004：schema_format（structure.sql）
