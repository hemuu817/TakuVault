# Runbook: preview 環境の R2 永続化 / ActiveStorage / Solid Queue 運用確認

## 位置づけ
- 本runbookは、preview 単一環境における Cloudflare R2 永続化と ActiveStorage 関連ジョブの運用確認・障害切り分け手順をまとめた文書である。
- 実装・設定の正本は ADR-0012 とする。
- 環境呼称と実行モードの正本は ADR-0011 とする。
- 受け入れ条件（AC/DoD）の正本は GitHub Issue 本文とする。
- 進捗（Done / CLOSED）の正本は `docs/issues_snapshot.md` とする。
- 本runbookは実装ルールを追加しない。ADR / Issue に従って追随更新する。

## 対象
- preview 単一環境
- `RAILS_ENV=production`
- ActiveStorage service `:r2`
- Cloudflare R2
- Solid Queue（primary DB 同居）
- Render Web + Worker の2プロセス構成
- ActiveStorage 関連ジョブ
  - `purge_later`
  - `analyze`
  - `variant(transform)`

## 対象外
- staging / production の複数環境分離
- バケット分割
- Redis + Sidekiq への移行
- 容量/形式/413/422 の仕様本体
- 削除整合の仕様本体
- Epic G（docs/issues/0036.md〜0040.md）の変換機能
  - ここで扱う `variant(transform)` は ActiveStorage の派生処理であり、Epic G の変換機能とは別物

## 参照正本
- ADR-0011: 環境の呼称・分離方針（単一環境 preview）
- ADR-0012: ActiveStorage（R2）/ Solid Queue / Render運用の正本
- ADR-0005: job基盤の一般方針と最小検証手順
- GitHub #24 / docs/issues/0024.md: Asset削除整合性
- GitHub #35 / docs/issues/0035.md: 容量/ファイル上限方針
- README.md

## 事前前提チェック
- Render 上で Web Service と Worker Service が存在すること
- Worker Service が `bin/jobs start` で起動していること
- preview 環境が `RAILS_ENV=production` で動作していること
- ActiveStorage service が `:r2` に固定されていること
- R2 用環境変数が投入済みであること
- `APP_HOST` が設定済みであること
- Render の Pre-Deploy Command で `bin/rails db:migrate` が実行される構成であること
- Solid Queue 用 migration が適用済みであること
- Worker 起動時に queue テーブル不足で失敗していないこと

## 運用上の注意
- Web / Worker のスレッド数と DB pool は必ず整合させる
  - `RAILS_MAX_THREADS`
  - `database.yml pool`
  - または `DATABASE_URL?pool=`
- Worker 停止時は `purge_later` / `analyze` / `variant(transform)` が滞留する
- ActiveStorage 関連ジョブは default queue 前提で確認する
- Direct Upload は採用しない。アップロードはサーバ経由 multipart 前提である
- R2 では S3 互換差異の回避として path-style（`force_path_style: true`）前提で確認する

## 最低限の確認観点

### 1. 永続化確認
1. 小さいファイルを1つアップロードする
2. 一覧/詳細で参照できることを確認する
3. preview 環境を再デプロイする
4. 再デプロイ後も同じ添付を参照できることを確認する

### 2. ジョブ基盤確認
1. Worker が起動していることを確認する
2. `analyze` が滞留していないことを確認する
3. 画像派生表示を使う箇所がある場合、`variant(transform)` が滞留していないことを確認する
4. `purge_later` が滞留していないことを確認する
5. default queue 前提でログ確認できることを確認する

### 3. 削除基盤確認
1. Asset を削除する
2. 画面上で参照不能になることを確認する
3. `purge_later` が完走していることをログで確認する
4. 削除整合の詳細確認は GitHub #24 / docs/issues/0024.md の観点に従う
   - R2 上の実体削除確認
   - ActiveStorage（Blob / Attachment）非残骸化確認

## 障害切り分け

### 症状: 再デプロイ後に添付が見えない
確認点:
- ActiveStorage service が local ではなく `:r2` になっているか
- R2 環境変数が誤っていないか
- `APP_HOST` が不足していないか
- preview 環境で誤った bucket / endpoint を見ていないか
- `force_path_style: true` が崩れていないか

### 症状: upload は通るが取得や表示が不安定
確認点:
- R2 endpoint / bucket / region が一致しているか
- `force_path_style: true` が崩れていないか
- Worker 依存の処理が失敗していないか
- 画像派生表示が必要な箇所で `variant(transform)` が失敗していないか

### 症状: 削除後も実体削除が進まない
確認点:
- Worker が停止していないか
- queue の滞留がないか
- `purge_later` 実行ログが出ているか
- GitHub #24 / docs/issues/0024.md で定義した削除フローと実装がずれていないか

### 症状: 解析や派生生成が進まない
確認点:
- Worker が起動しているか
- `analyze` / `variant(transform)` が失敗していないか
- queue テーブル不足で Worker が落ちていないか
- 依存不足により ActiveStorage の派生処理が失敗していないか

### 症状: DB 接続タイムアウトが出る
確認点:
- Web / Worker の `RAILS_MAX_THREADS` と DB pool が整合しているか
- Worker 数や並列度変更が pool に反映されているか
- `ActiveRecord::ConnectionTimeoutError` がログに出ていないか

## 更新ルール
- 実装方式が変わった場合は ADR-0012 を先に更新する
- 受け入れ条件が変わった場合は GitHub Issue 本文を先に更新する
- runbook は ADR / Issue に従って追随修正する
- runbook 単独で実装ルールやスコープを増やさない