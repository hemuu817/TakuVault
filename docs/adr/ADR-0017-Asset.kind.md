# ADR-00XX：Asset.kind（content_type 自動判定・分類責務の明確化）

## Status
Accepted

## Context

TakuVaultでは Asset 一覧、未整理導線、Where used入力補助で「素材種別」を安定して扱う必要がある。

既存の ADR-0002 では `image`, `audio`, `video`, `other` を Asset.kind として定義していたが、現方針では動画ファイルを扱わない。

そのため、Asset.kind はアップロード済みAssetの分類として `other`, `image`, `audio` に整理し、許可/拒否の責務とは分離する。

## Decision

### D1. kind はDBに永続化する（enum/int）

- `assets.kind` は **enum（int） / NOT NULL / default: other** とする。
- kind はAssetの分類軸として扱う。
- kind は許可/拒否の判定結果ではなく、アップロード済みAssetの分類である。

### D2. enum の数値割当（固定）

> **本ADR採用後の整数値は将来変更しない**。kind追加は別ADR/Issueで扱う。

- `other: 0`
- `image: 1`
- `audio: 2`

### D3. kind 値

- Asset.kind の値は以下に固定する。
  - `other`
  - `image`
  - `audio`
- `video` は定義しない。
- `video: 3` は予約値として残さない。

### D4. 判定ルール

- 本ADRの判定ルールは、ADR-0014の許可/拒否を通過したAssetに対する分類ルールである。
- `image/*` → `image`
- `audio/*` → `audio`
- 上記以外 → `other`
- `video/*` を許可して `other` として保存する、という意味ではない。
- 動画ファイルの許可/拒否は本ADRでは扱わず、ADR-0014を正本とする。

### D5. content_type の信頼境界（固定）

- 判定の入力は **ActiveStorage Blob が保持する `content_type`** を唯一の根拠とする。
  - リクエストパラメータ由来の `kind` / `content_type` は信頼しない。
- `content_type` が不明/曖昧な場合は **`other`** に分類する。
  - 例：`application/octet-stream`
  - 空
  - 判定対象外のMIME

### D6. 手動変更は対象外

- kind の手動編集UI、手動上書きAPIは提供しない。
- kind はサーバ側で自動決定され、ユーザー入力で変更できない。

### D7. 添付差し替え

- 添付差し替えは本ADRでは扱わない。
- ファイルを変更したい場合は **新規Assetとして作成**する。
- 将来、添付差し替えを導入する場合は、kind再判定の扱いを別ADR/Issueで定義する。

### D8. 許可/拒否との責務分離

- アップロード安全性（許可Content-Type、拡張子、サイズ上限、総容量上限）は本ADRでは扱わない。
- 許可形式・拒否形式・エラー区分は ADR-0014 を正本とする。
- kind は「分類」であり、「拒否」の責務を持たない。
- 形式不正のファイルを `other` として受け入れる、という意味ではない。
- 許可/拒否を通過したAssetに対して、分類結果として kind を付与する。

### D9. Usage.role との関係

- Asset.kind から Usage.role を自動決定しない。
- Usage.role は、ADR-0006に従い、Usage作成時の入力項目として扱う。
- Asset.kind は、UI上の Usage.role 候補表示補助には使ってよい。
- kind-role 不一致は、サーバ側で拒否しない。

### D10. 導入時バックフィル（保守ガード）

- 既存Assetが存在する状態で本ADRの分類体系へ移行する場合、既存Assetのkindは実装Issueでバックフィル方針を決める。
- バックフィル方法は、以下のいずれかを実装Issueで選択する。
  - 既存値を `other` へ寄せる。
  - 添付済みBlobの `content_type` から再計算する。
- 既存データに `kind = 3` が存在する場合、`video` を残さず、実装Issueで `other` 等への移行方針を定義する。

### D11. 旧ADRの扱い

- 本ADRは ADR-0002 を置き換える。
- 本ADRが Accepted になった場合、旧 ADR-0002 の Status は Superseded に更新し、本ADRへの参照を追記する。
- 旧 ADR-0002 の履歴は削除しない。

## Consequences

- Asset.kind の分類体系から `video` が外れ、現方針で扱う `image` / `audio` / `other` に整理される。
- Asset.kind とアップロードValidationの責務が分離されるため、分類と拒否判定の混同を避けられる。
- `video: 3` を予約値として残さないため、将来の動画対応を既定路線として誤読されにくくなる。
- `video` を将来扱う場合は、別ADRで分類体系・許可形式・変換処理・表示仕様を再検討する必要がある。
- Asset.kind から Usage.role を自動決定しないため、ADR-0006のUsage作成ルールと矛盾しない。
- UI上の候補表示補助には使えるため、image系素材には画像系role、audio系素材には音声系roleを提示しやすくなる。
- 既存データに `kind = 3` がある場合は、実装Issueで移行方針を明示する必要がある。
- Where usedツリーや絞り込み表示側での kind の扱いは、本ADRでは決めない。必要に応じて該当ADR/Issueに従う。

## Supersedes

- ADR-0002：Asset.kind（content_type 自動判定・手動変更なし）

## Related

- ADR-0002：Asset.kind（content_type 自動判定・手動変更なし）
- ADR-0006：Usage割当ルール（未整理一括割当 / 冪等 / 所有権整合）
- ADR-0009：ADR運用ルール（正本化・参照境界・改訂手順）
- ADR-0014：許可形式・判定方式・エラーハンドリング
- ADR-00XX：Session詳細「セッション素材一覧」表示仕様（用途表示順の固定化）
- ADR-0010：Where used ツリー遅延ロード契約（Proposed。表示・絞り込み側の参考）