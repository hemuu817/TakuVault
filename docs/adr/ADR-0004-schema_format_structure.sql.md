# ADR-0004：PostgreSQLにおけるSQL形式のスキーマ保存

## Status

Proposed

既存の設計・実装で採用されているスキーマ保存方式を記録するための草案。

## Context

TakuVaultはPostgreSQLを使用し、NOT NULL、一意制約、CHECK、外部キーなどによってDBの整合性を保証している。

現行実装ではSQL形式のスキーマ保存を採用し、`db/structure.sql`をバージョン管理している。本ADRでは、この保存方式と採用理由を明文化する。

## Decision

### D1. PostgreSQLを前提としたSQL形式を使用する

スキーマの保存形式はSQLとする。

Railsの設定は、`config/application.rb`の次の指定による。

```ruby
config.active_record.schema_format = :sql
```

スキーマ成果物には`db/structure.sql`を使用する。

### D2. DB制約・Indexを含む構造をSQLで記録する

SQL形式の採用理由は、PostgreSQL上のDB制約・Indexを含む構造をSQLとして保存するためである。

Ruby形式のスキーマ表現範囲に依存せず、採用しているPostgreSQLの構造を記録する方式とする。

この判断は、現行のCHECK・複合外部キーなどがすべて`schema.rb`では表現できないことを前提としない。

### D3. migrationとスキーマ成果物の役割を区別する

- `db/migrate/`は、DB構造を変更する処理を保持する。
- `db/structure.sql`は、ダンプ時点のDB構造を保持する。
- ADRは、その構造・方式を採用した設計理由を保持する。

個別の制約の意味や業務上の不変条件は、対応するADRを参照する。

### D4. primary DBに含まれる構造を保存する

現行の`db/structure.sql`は、業務テーブルに加えてActive Storage・Solid Queueのテーブルを含む。

Solid Queueをprimary DBに同居させ、通常のmigrationで管理する判断はADR-0015を正本とする。本ADRでは、その構成に対するスキーマ保存方式を記録する。

## Consequences

- DB制約・Indexを含む構造を、SQLの成果物として参照できる。
- DB間の移植性より、採用しているPostgreSQLの構造を記録することを優先する。
- SQL形式の生成・復元はPostgreSQLのツールに依存し、ツールのバージョンによって生成内容や復元互換性の影響を受ける。
- SQLダンプに保存されるDB構造と、アプリケーションが保証する認可・validation・callbackの責務は区別される。
- スキーマの保存は、ユーザーデータやR2上の原本ファイルのバックアップを意味しない。

## 記録の根拠と範囲

実装の確認基準は、2026-09-18の調査メモが対象としたコミット`4eb4dca4b0e6f08b9d23eb8886144f8ebc712fa0`とする。

- `config/database.yml`はPostgreSQLを指定している。
- `config/application.rb`は`schema_format = :sql`を指定している。
- `db/structure.sql`がバージョン管理されている。

稼働中の開発DB・Render上のDBへの適用状態や、ダンプの復元成功を示す記録ではない。

調査メモでは古い`db/schema.rb`の残存も確認されているが、その整理方法は本ADRでは決定しない。

## Out of Scope

- 新しいDB制約やIndexの追加
- 既存の業務設計・所有権・削除方針の変更
- `db/schema.rb`の削除などのリポジトリ整理
- 新たなmigration運用・検証手順の導入
- DB・クライアントのバージョン統一
- バックアップ・復旧方針の策定

## Related

- ADR-0001：default_scene
- ADR-0006：Usage割当ルール
- ADR-0007：所有権の正本と混在禁止
- ADR-0009：ADR運用ルール
- ADR-0015：ActiveStorage（R2）/ Solid Queue / Render運用の正本
- ADR-0017：Asset.kind
- 「DB設計判断の整理 — ADR作成用調査メモ」（2026-09-18）
- [config/application.rb（確認対象コミット）](https://github.com/hemuu817/TakuVault/blob/4eb4dca4b0e6f08b9d23eb8886144f8ebc712fa0/config/application.rb)
- [config/database.yml（確認対象コミット）](https://github.com/hemuu817/TakuVault/blob/4eb4dca4b0e6f08b9d23eb8886144f8ebc712fa0/config/database.yml)
- [db/structure.sql（確認対象コミット）](https://github.com/hemuu817/TakuVault/blob/4eb4dca4b0e6f08b9d23eb8886144f8ebc712fa0/db/structure.sql)