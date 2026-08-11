# ADR-0015：ActiveStorage（R2）/ Solid Queue / Render運用の正本（Rails 8.1.3）

## ステータス
Accepted

> 本ADRは ADR-0012 の後継として提案中。Rails 8.1.3 上の実装済み構成の追認として、確認完了後に `Accepted` へ変更する。
> 状態遷移の順序：
> 1. 本ADRを `Accepted` にする。
> 2. その後、ADR-0012 を `Superseded` にし、本ADRへの参照を追記する。
> 3. README等の ADR-0012 参照を本ADRへ差し替える。
> 「ADR-0012のSuperseded化」「README差し替え」は Accepted 後の作業とし、Accepted 前の着手はしない（ADR-0009 §4「Proposedはこれを前提に実装を開始しない」）。

## 位置づけ（ADR-0012との関係）
- TakuVault は Rails 8.1.3 へアップグレード済みであり、Rails 7.2.3 前提の ADR-0012 は前提が古くなった。
- 一方で、ADR-0012 で確定した Cloudflare R2 / ActiveStorage / Solid Queue / Render Web + Worker / primary DB 同居 / `bin/rails db:migrate` の骨格は Rails 8.1.3 後も維持できる。
- 本ADRは ADR-0012 を **Rails 8.1.3 前提で置き換える正本** とする。Rails 8系標準構成との差分を明示したうえで、ActiveStorage / Job / Render 運用の正本を再定義する。
- ADR-0012 は Rails 7.2.3 前提の判断履歴として残し、本文改変は最小限に留め `Superseded by ADR-0015` を追記する。基本方針は維持する。
- Issue本文には、本ADRの具体設定値・adapter名・envキー詳細を再掲しない。Issue本文は目的・作業内容・AC・検証観点に限定し、具体運用の正本は本ADRとする。
- 前提：Rails runtime は `8.1.3` 系。現在のアプリケーションは `config.load_defaults 8.1` で動作する。本ADRは framework defaults の採用可否や Rails 8.1 新機能活用そのものを目的とせず、ActiveStorage / Solid Queue / Render 運用を扱う。

## 決定（曖昧語なし）
- 永続ストレージ：Cloudflare R2（S3互換）を ActiveStorage の正とする
- アップロード：Direct Upload 不採用（サーバ経由 multipart で統一）
- Job基盤：Solid Queue（DB-backed）を採用し、workerを常時稼働させる
- Solid Queue のDB方針：**primary DB に同居**（queue DB は分離しない / `connects_to` 不採用 / `db/queue_schema.rb` 不採用）
- Render構成：Web Service + Worker Service の2プロセス構成に固定する
- migrate方式：Renderの Pre-Deploy Command で `bin/rails db:migrate` を実行（`db:prepare` は正本にしない）
- URL host：`APP_HOST` を必須化し、productionで `default_url_options[:host]` を設定する
- preview環境：Render上は preview の単一構成（`RAILS_ENV=production`）。staging/production 分離は扱わない

## 永続ストレージ
- 永続ストレージは Cloudflare R2（S3互換）を ActiveStorage の正とする。
- preview（`RAILS_ENV=production`）では、ActiveStorage の service key を `:r2` に固定する。
- productionでは `config.active_storage.service = :r2` を固定する。
- R2以外のストレージ方式は本ADRでは扱わない。

## アップロード方式
- ActiveStorage Direct Upload は採用しない。
- アップロード方式は、サーバ経由 multipart に統一する。
- 理由は、アップロード時の容量・件数・Content-Type・拡張子・総容量判定をサーバ側で一貫して行うため。
- Direct Upload 採用検討は本ADRの非スコープとする。

## 必須依存
- S3互換ストレージとして Cloudflare R2 を ActiveStorage から利用するため、`aws-sdk-s3` を導入する。
  - `gem "aws-sdk-s3", require: false`
- Job基盤として Solid Queue を利用するため、`solid_queue` を導入する。
  - `gem "solid_queue"`

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
- `endpoint`：`ENV["R2_ENDPOINT"]` から注入
- `bucket`：`ENV["R2_BUCKET"]` から注入
- `access_key_id`：`ENV["R2_ACCESS_KEY_ID"]` から注入
- `secret_access_key`：`ENV["R2_SECRET_ACCESS_KEY"]` から注入
- `region`：`ENV["R2_REGION"]` から注入
- S3互換差異による事故を避けるため、`force_path_style: true` を採用する。
- productionでは、R2必須envが空または未設定の場合に起動時点で失敗させる。

## `config/environments/production.rb` の固定
- `config.active_storage.service = :r2`
- `config.active_job.queue_adapter = :solid_queue`
- `Rails.application.routes.default_url_options[:host] = ENV.fetch("APP_HOST")`

`APP_HOST` は、ActiveStorage URL生成などアプリケーション外部から参照されるURL生成で必要になるため、productionでは必須とする。

## Job基盤
- Job基盤は Solid Queue（DB-backed）を採用する。
- Workerを常時稼働させる。
- Redisは導入しない。
- 本番（preview、`RAILS_ENV=production`）では、ActiveStorage の以下の処理を成立させるため、Job基盤を必須とする。
  - `purge_later`
  - `analyze`
  - `variant(transform)`
- Workerが停止している場合、purge / analyze / transform が滞留し、ストレージのクリーンアップや解析が完了しない（＝削除整合が崩れる）。
- したがって、Render上では Web Service とは別に Worker Service を常時稼働させる。

## Solid Queue のDB方針
- Solid Queue は primary DB に同居させる。
- queue DB は分離しない。
- `db/queue_schema.rb` は最終成果物として採用しない。
- Solid Queue用テーブルは通常の migration として管理する。
- `config.solid_queue.connects_to` による queue DB 分離設定は採用しない。
- 理由は、現時点のTakuVaultでは、Render運用の単純さと既存構成との整合を優先するため。

## Solid Queue（導入成果物）
Solid Queue運用に必要な成果物は以下とする。

- `config/queue.yml`
- `config/recurring.yml`
- `bin/jobs`
- `db/migrate/*solid_queue*`（Solid Queue用テーブル作成 migration）

`config/recurring.yml` は production における Solid Queue の定期ジョブ設定として扱う。現時点では、finished job cleanup を定期実行する用途を持つ。

- `SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)`

Workerのqueue対象を将来 `*` から絞る場合は、`solid_queue_recurring` queue を処理対象に含める。

### 導入時の必須除去作業（単一DB構成のため）
`bin/rails solid_queue:install` は queue DB 分離前提の成果物・設定を生成する。本ADRは primary DB 同居のため、導入時に以下を必ず除去する。

- `config/environments/production.rb` から `config.solid_queue.connects_to = { database: { writing: :queue } }` を削除する（installerが自動追記するため、残すと存在しないqueue DBへ接続しに行く）。
- `db/queue_schema.rb` は、内容を `db/migrate/*solid_queue*` migration へ移したうえで削除する。
- `config/database.yml` に queue 用の別DB接続（`queue:` ブロック／`migrations_paths: db/queue_migrate`）を追加しない。

以上により、後述の migrate方式（`bin/rails db:migrate` / `db:prepare` 不採用）で Solid Queue 用テーブルを通常 migration として管理できる。

## ActiveStorage関連ジョブのqueue方針
- 現行運用では、ActiveStorage関連ジョブは default queue に統一する。
- ActiveStorageのqueue分離は本ADRでは行わない。
- queue分離が必要になった場合は、ジョブ量・失敗率・滞留状況を確認したうえで、別Issueまたは別ADRで検討する。

## Render構成（起動コマンド固定）
Render構成は以下に固定する。

- Web Service：Railsアプリケーションを起動する。
- Worker Service：Solid Queue Workerを起動する。起動コマンドは `bin/jobs start`。

Web / Worker は同じ `DATABASE_URL` を参照する。

## migrate方式
- preview環境では、Renderの Pre-Deploy Command で `bin/rails db:migrate` を実行する。
- `db:prepare` は正本にしない。
- 理由は、TakuVaultでは Solid Queue を primary DB に同居させ、queue DB分離を採用しないため。
- migrationは通常のRails migrationとして管理する。
- queue DB分離を将来採用する場合は、migrate方式も別ADRまたは別Issueで再定義する。

## 運用上の注意（差し戻し回避）
- Web / Worker のスレッド数と DB pool の整合を取る。
- `RAILS_MAX_THREADS` と `database.yml pool`、または `DATABASE_URL?pool=` の値を確認する。
- 不一致は `ActiveRecord::ConnectionTimeoutError` の原因になる。
- Worker側の `JOB_CONCURRENCY`、`config/queue.yml` の `threads`、DB pool の関係を確認対象に含める。

## preview環境
- Render上の環境は preview の単一構成とする。
- Rails実行モードは `RAILS_ENV=production` とする。
- staging / production の分離は本ADRでは扱わない。
- R2バケットのstaging / production分割も本ADRでは扱わない。
- 環境分離が必要になった場合は、別ADRまたは別Issueで扱う。

## Rails 8標準構成との差分
Rails 8系では Solid Queue が標準寄りのDB-backed queueとして扱われる。ただし、TakuVaultでは以下のRails 8標準寄り構成を採用しない。

- queue DB分離
- `db/queue_schema.rb` の正本化
- queue DB分離前提の `db:prepare`
- 複数DB前提の migration 運用

採用しない理由は以下とする。

- Renderで管理するDB接続・環境変数・migration手順が増えるため。
- 現時点の主なジョブ用途は ActiveStorage の purge / analyze / variant であり、queue DB分離の運用コストに見合う効果が限定的なため。
- 小規模ポートフォリオとして、まず基礎機能の安定運用を優先するため。
- 将来、ZIPエクスポート・大量Asset処理・変換ジョブ・AI分類ジョブなどでジョブ量が増えた場合は、別ADRまたは別Issueで queue DB分離を再検討する。

## 影響（Consequences）
- ADR-0012の骨格を維持するため、Rails 8.1.3移行後もR2 / Solid Queue / Render運用の考え方が大きく変わらない。
- queue DB分離を採用しないため、Render上のDB接続・migration・環境変数管理を単純に保てる。
- primary DB同居のため、ジョブ量が増えた場合はアプリDBへの負荷が増える可能性がある。
- 将来、ZIPエクスポート・変換ジョブ・AI分類などでジョブ量が増えた場合は、queue DB分離を再検討する必要がある。
- Active Job Continuations と Structured Event Reporting を非スコープにすることで、今回のADRは基礎運用の正本化に集中できる。
- READMEやIssue本文がADR-0012を参照している場合は、本ADRへの参照差し替えが必要になる。
- 旧ADR-0012は履歴として残るため、Rails 7.2.3時点の判断も追跡できる。

## 受け入れ条件
### A. 本ADRの記述要件（Accepted化の前に満たす）
- [ ] 本ADRが ADR-0012 の後継ADRであることが明記されている。
- [ ] Rails 8.1.3 前提であることが明記されている。
- [ ] productionで `:r2` / `:solid_queue` / `APP_HOST` が維持されている。
- [ ] Cloudflare R2 を ActiveStorage の正本とすることが明記されている。
- [ ] Direct Upload 不採用が明記されている。
- [ ] Solid Queue を Job基盤として採用することが明記されている。
- [ ] Solid Queue は primary DB 同居とし、queue DBを分離しないことが明記されている。
- [ ] `config.solid_queue.connects_to` を採用しないことが明記されている。
- [ ] `db/queue_schema.rb` を最終成果物として採用しないことが明記されている。
- [ ] `db:prepare` を正本にしないことが明記されている。
- [ ] Renderの Pre-Deploy Command は `bin/rails db:migrate` とすることが明記されている。
- [ ] Renderは Web Service + Worker Service の2プロセス構成とすることが明記されている。
- [ ] Worker Service の起動コマンドが `bin/jobs start` に固定されている。
- [ ] `config/recurring.yml` を Solid Queue の導入成果物に含めている。
- [ ] `solid_queue_recurring` queue を将来のqueue絞り込み時に処理対象へ含める注意が明記されている。
- [ ] ActiveStorage関連ジョブは現行では default queue 統一とすることが明記されている。
- [ ] Active Job Continuations を本ADRの非スコープとしている。
- [ ] Structured Event Reporting を本ADRの非スコープとしている。

### B. Accepted化に伴う移行作業（Accepted後に実施）
- [ ] ADR-0012 を `Superseded` にし、本ADRへの参照を追記している（本文は改変しない）。
- [ ] README の ADR-0012 参照を本ADRへ差し替えている（参照箇所を実ファイルで確認のうえ実施）。
- [ ] Superseded運用をプロジェクト方針として確定している（ADR-0009 が `Proposed` のため運用可否を確認）。

## 非スコープ（ここでは決めない）
本ADRでは以下を採用・設計しない。

- Active Job Continuations
- Structured Event Reporting
- queue DB分離
- `db/queue_schema.rb` の正本化
- `db:prepare` 前提のRender運用
- Kamal運用への移行
- 監視基盤の本格整備
- ZIPエクスポート
- 大量Asset処理
- 変換ジョブ
- AI分類ジョブ
- R2以外のストレージ方式
- ActiveStorage Direct Upload

Active Job Continuations は、長時間ジョブが必要になるZIPエクスポート、大量Asset処理、変換ジョブ、AI分類ジョブで再検討する。
Structured Event Reporting は、監視改善、ジョブ失敗分析、アップロード拒否理由の集計、利用状況分析で再検討する。

## 参照
- ADR-0005：job基盤の採用方針
- ADR-0009：ADR運用ルール（正本化・参照境界・改訂手順）
- ADR-0011：単一環境 preview 方針
- ADR-0012：ActiveStorage（R2）/ Solid Queue / Render運用の正本（Rails 7.2.3 / Superseded）
- ADR-0013：容量・上限の定義と算定ルール
- ADR-0014：許可形式・判定方式・エラーハンドリング
- README.md
- AGENTS.md