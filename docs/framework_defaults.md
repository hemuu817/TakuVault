# Rails 8.x framework defaults 採用記録

Issue #152「Rails 8.x framework defaults 段階適用」の判断記録。
Rails本体は8.1.3のまま、Rails 8.0 defaultsの個別検証、
`config.load_defaults 8.0`、Rails 8.1 defaultsの個別検証を経て、
`config.load_defaults 8.1`を採用した。

Rails 8.1.3で確認対象となるversioned defaultsは9項目である。
内訳はRails 8.0由来の2項目とRails 8.1由来の7項目。
`spec/config/framework_defaults_spec.rb`では、この9項目に加えて、
歴史的な`to_time`互換挙動を1件確認するため、合計10 examplesとしている。

## Rails 8.0

Rails 8.0.0のConfiguring Guideには3項目が掲載されていたが、
Rails 8.1.3では`config.active_support.to_time_preserves_timezone`がdeprecatedとなり、
`to_time`は常にreceiverのtimezoneを保持する。

| 設定 | 判断 | 理由 |
|---|---|---|
| `Regexp.timeout = 1` | 採用 | アプリ内の正規表現利用を確認し、既存テストがgreen |
| `config.action_dispatch.strict_freshness = true` | 採用 | 独自freshness処理がなく、ActiveStorageを含む既存導線がgreen |
| `config.active_support.to_time_preserves_timezone = :zone` | 設定不要 | Rails 8.1.3で同挙動が常時有効。deprecated warningを避けるため代入しない |

## Rails 8.1

| 設定 | 判断 | 理由 |
|---|---|---|
| `config.action_controller.action_on_path_relative_redirect = :raise` | 採用 | redirect先はroute helperで生成 |
| `config.action_controller.escape_json_responses = false` | 採用 | JSON responseやHTML内JSON埋め込みなし |
| `config.action_view.remove_hidden_field_autocomplete = true` | 採用 | Devise・CRUDフォームの回帰確認済み |
| `config.action_view.render_tracker = :ruby` | 採用 | ERB、Tailwind build、assets precompileがgreen |
| `config.active_record.raise_on_missing_required_finder_order_columns = true` | 採用 | 暗黙順序に依存するfinderなし |
| `config.active_support.escape_js_separators_in_json = false` | 採用 | JavaScriptへのJSON埋め込みなし |
| `config.yjit = !Rails.env.local?` | 採用 | testでは無効、production相当bootでは有効になることを確認 |

## 検証方法

プロジェクトルートで以下を実行する。

```bash
grep -R -nE 'load_defaults|active_support\.to_time|framework default|8\.0|8\.1' config spec docs/framework_defaults.md
bin/rspec spec/config/framework_defaults_spec.rb
```

grepでは`config.load_defaults 8.1`と9項目のversioned defaultsに加え、
Rails 8.0.0当時の設定だった`to_time`のtimezone保持挙動に関する記録を確認する。
RSpecの期待結果は`10 examples, 0 failures`とする。

正本はRails公式の[Configuring Rails Applications](https://guides.rubyonrails.org/configuring.html#versioned-default-values)とする。
