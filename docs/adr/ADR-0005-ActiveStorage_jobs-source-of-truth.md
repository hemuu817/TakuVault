# 付録A：実装メモ（job基盤の採用方針）

## 方針
- ActiveJob を DB-backed の queue_adapter で動かす（Redis不要）
- worker プロセスを常時稼働させる
- 採用する実装（例：Solid Queue 等）は Rails minor に合わせて確定する

## 最低限決めること（Issue本文に書かない）
- 採用する queue_adapter の具体名
- worker の起動コマンド
- queue用テーブルを同一DBに置くか分けるか（MVPは同一DB推奨）

# 付録B：staging相当の最小検証手順（手動）

1. web/worker を起動している状態にする（workerが止まっていないこと）
2. 小さいファイルを1つアップロード
3. 一覧/詳細で参照できることを確認
4. アプリを再デプロイして、再度参照できることを確認
5. purge_later 相当の削除操作を行い、以下を確認
   - 画面上で参照不能になる
   - DB側で Attachment/Blob が残っていない（件数や関連で確認）
6. stg/prod がバケット分割されていることを確認（混入なし）
