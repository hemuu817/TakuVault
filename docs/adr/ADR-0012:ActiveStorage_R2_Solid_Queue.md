# 2) ADR-0012：ActiveStorage（R2）/ Solid Queue / Render運用の正本（Rails 7.2.3）

## ステータス
Accepted

## 位置づけ（ADR-0005との関係）
- ADR-0005 は「一般方針（DB-backed + worker 常時稼働）」の正本。
- 本ADR（ADR-0012）は **Rails 7.2.3 前提で“具体実装を確定する”正本** とする。
- Issue本文には具体実装（adapter名・コマンド・envキー詳細）を再掲せず、本ADRを参照する。
- 本番（preview、`RAILS_ENV=production`）では、Active Storage の service key を **`:r2`** に固定し、Cloudflare R2 を永続ストレージの正本とする。

## 決定（曖昧語なし）
- 永続ストレージ：Cloudflare R2（S3互換）を ActiveStorage の正とする
- アップロード：Direct Upload 不採用（サーバ経由 multipart で統一）
- Job基盤：Solid Queue（DB-backed）を採用し、workerを常時稼働させる
- Render構成：Web Service + Worker Service の2プロセス構成に固定する
- migrate方式：Renderの Pre-Deploy Command で `bin/rails db:migrate` を実行（方式固定）
- URL host：`APP_HOST` を必須化し、productionで `default_url_options[:host]` を設定する

## 必須依存
- S3互換（R2）を ActiveStorage の service として使うため、`aws-sdk-s3` を導入する
  - `gem "aws-sdk-s3", require: false`

## 環境変数（キー名を固定）
### R2（ActiveStorage用）
- `R2_BUCKET`
- `R2_ENDPOINT`
- `R2_REGION`
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`

### アプリURL
- `APP_HOST`

### 基本（Render）
- `DATABASE_URL`
- `SECRET_KEY_BASE`
- `RAILS_ENV=production`

## `config/storage.yml` 規約
- サービス名：`:r2`
- `endpoint`：`ENV["R2_ENDPOINT"]`
- `force_path_style: true` を原則採用（S3互換で詰まりやすい箇所の先回り）
- bucket/credentials/region は上記envから注入する

## `config/environments/production.rb` の固定
- `config.active_storage.service = :r2`
- `config.active_job.queue_adapter = :solid_queue`
- `Rails.application.routes.default_url_options[:host] = ENV.fetch("APP_HOST")`

## Solid Queue（導入成果物）
- `config/queue.yml`
- `config/recurring.yml`
- `db/queue_schema.rb`
- `bin/jobs`

### R2互換性（addressing style）
- R2のS3互換差異による事故を避けるため、**path-style**（`force_path_style: true`）を採用する。

## Render 起動コマンド（固定）
- Web Service：アプリ起動（(3)で確定したもの）
- Worker Service：`bin/jobs start`

## 運用上の注意（差し戻し回避）
- Web/Worker のスレッド数と DB pool の整合を取ること（不一致は `ActiveRecord::ConnectionTimeoutError` の原因）
  - `RAILS_MAX_THREADS` と `database.yml pool`（または `DATABASE_URL?pool=`）の整合を必ず確認する
- worker停止時は `purge_later` が滞留する（= 削除整合が壊れる）。workerは常時稼働を前提とする。

### 本番のジョブ基盤（Active Storageのpurge_later / analyze成立条件）
- 本番（preview、`RAILS_ENV=production`）では、Active Storage の `analyze` / `purge_later` を処理するため、ジョブ基盤を **用意必須**とする。
- キューバックエンドは **Solid Queue（DB-backed）** とする。
- Renderは **Web + Worker の2プロセス**運用とし、Workerの起動コマンドは **`bin/jobs start`** に固定する。
- MVPでは、Active Storage関連ジョブは **default queue に統一**する。
- Workerが停止している場合、purge/analysisジョブが滞留し、ストレージのクリーンアップが完了しない（＝削除整合が崩れる）。

## 受け入れ条件（Yes/No）
- [ ] worker が稼働し、`purge_later` が滞留しない（ログで確認可能）
- [ ] 再デプロイ後も添付が参照できる（R2永続）
- [ ] 削除後、R2上の実体削除と ActiveStorage（Blob/Attachment）非残骸化が確認できる
- [ ] Direct Upload 不採用が docs/README に明記されている

## 非スコープ（ここでは決めない）
- 上限値（サイズ/Content-Type/拡張子）の確定：Issue (27)
- 不正ファイル拒否の実装：Phase 0 の Asset側Issue
- UI/UX：Phase 0 の Asset側Issue

## 参照
- ADR-0005：job基盤の採用方針（一般方針）
- ADR-0008：単一環境（preview）方針
