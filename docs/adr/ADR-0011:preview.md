# 2) ADR-0011：環境の呼称・分離方針（単一環境 preview）

## ステータス
Accepted

## 背景 / 課題
- Issue本文に “staging” が残ると、環境を分けるのか分けないのかが曖昧になり混乱を招く。
- 一方で、Railsの実行モードは production 相当設定（`RAILS_ENV=production`）で動かす必要があるため、
  「環境の呼称」と「Rails実行モード」を混同すると差し戻しリスクが高い。
- 既存ADR（ADR-0005）には “staging相当” や “stg/prodバケット分割確認” が含まれるが、
  本プロジェクトの現方針（単一環境）と整合させる必要がある。

## 決定
1. Render上の環境は **単一** とし、呼称は **preview** とする（staging/prod は作らない）
2. Railsの実行モードは `RAILS_ENV=production` とする（production相当設定）
3. ADR-0005 の “staging相当” は **preview** を指すものとして読み替える
4. ADR-0005 の “stg/prodバケット分割確認” は **将来の別Issue/別ADR** で扱う（MVP/Phase 0 の必須要件にしない）
   - staging/prod を追加する場合にのみ、R2バケット分割と環境変数分離を行う

## 影響（メリット/デメリット）
- メリット：用語矛盾が消え、講師レビューでの混乱（staging/prod論点）が再発しにくい。
- デメリット：staging/prod分離の運用は将来タスク化が必要（ただし現スコープでは過剰）。

## 受け入れ条件（Yes/No）
- [ ] Issue本文・README・docs に “staging/prod を前提とする” 文言が残存しない
- [ ] “preview（環境の呼称）” と “`RAILS_ENV=production`（実行モード）” の役割が矛盾なく説明されている
- [ ] ADR-0005 の staging 記述は本ADRの読み替えルールにより矛盾なく運用できる

## 参照
- ADR-0005：job基盤の採用方針（一般方針）
