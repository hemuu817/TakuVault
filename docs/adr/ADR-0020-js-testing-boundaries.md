# ADR-0020：JSテスト移行とRSpecの債務境界

## Status

Proposed

## Context

TakuVaultでは、本番JavaScriptの配信方式としてImportmapを使用している。

一方、JavaScript専用のテスト基盤が存在しなかった経緯から、Stimulus Controllerの詳細なDOM操作、キーボード操作、フォーカス制御など、本来JavaScript側で直接保証できる挙動の一部をRSpec System Specが担っている。

この状態では、JavaScript内部の細かな挙動を確認するためにもRailsアプリケーション全体とブラウザを起動する必要があり、テスト責務がSystem Specへ集中する。

また、System SpecはRails、DB、Turbo、JavaScriptを横断するE2E保証として引き続き必要であり、既存System Specそのものを負債として扱い、単純に件数を削減することも適切ではない。

そのため、本ADRでは以下を正本化する。

* 本番のImportmap構成を維持したままJavaScript専用テストを導入する境界
* jsdomと実ブラウザテストの責務
* RSpec Request Spec / Model Spec / Service Spec / System Specとの責務境界
* 既存System Specを別テスト層へ移行する場合の債務判定と移行条件

具体的なテストライブラリのバージョン、設定ファイル、CIコマンドおよび既存Specの個別移行は、実装Issueで扱う。

## Decision

### D1. 本番のImportmap構成を維持する

* 本番JavaScriptの配信方式はImportmapを維持する。
* JavaScriptテスト導入を理由として、本番アプリケーションをNode.jsベースのbundler構成へ移行しない。
* Node.js / npmは、JavaScriptの開発・テスト用途として導入してよい。
* テスト基盤の都合によって、本番JavaScriptの配信方式を変更しない。

### D2. JavaScriptテストの共通ランナーとしてVitestを採用する

* JavaScript専用テストの共通ランナーとしてVitestを採用する。
* JavaScriptテストを複数の独立したランナーへ不用意に分割しない。
* DOMシミュレーションを利用するテストと実ブラウザを利用するテストの双方を、可能な範囲でVitestを共通入口として扱う。
* JavaScriptテストの具体的なディレクトリ構成、設定ファイル名およびnpm scriptは実装Issueで決定する。

### D3. jsdomはStimulus ControllerおよびDOM状態の検証を担当する

* Vitest + jsdomを、JavaScript単体テストおよびDOMテストの基本層とする。
* 主な対象は以下とする。

  * Stimulus Controller内部の条件分岐
  * DOM属性・class・disabled状態等の変更
  * 入力値に応じた表示状態の変更
  * Controllerが発火させるDOM操作
  * ブラウザネイティブ挙動を必要としないイベント処理
* jsdom上で再現できることを、実ブラウザ上のネイティブ挙動の保証とはみなさない。
* focus、キーボード入力、event propagation、scroll、Browser API等、実ブラウザ上での挙動を保証する必要があるものはBrowser Modeで扱う。

### D4. 実ブラウザ保証にはVitest Browser Mode + Playwright providerを使用する

* 実ブラウザを必要とするJavaScriptテストにはVitest Browser Modeを使用する。
* Browser ModeのproviderとしてPlaywrightを使用する。
* 主な対象は以下とする。

  * 実際のフォーカス遷移
  * キーボード入力
  * event propagation
  * スクロール挙動
  * Browser API
  * jsdomでは再現または保証できないDOM挙動
* 独立したPlaywright Testランナーは初期構成では採用しない。
* Playwrightを使用すること自体と、Playwright Testを独立したテスト層として導入することを区別する。
* 将来、Vitest Browser Modeでは表現しにくいブラウザ横断E2E要件が生じた場合は、別の設計判断として再検討する。

### D5. Chromiumを必須ブラウザのベースラインとする

* JavaScript実ブラウザテストではChromiumを必須ベースラインとする。
* CIでもChromiumを実行対象とする。
* FirefoxおよびWebKitは初期導入時の必須対象に含めない。
* Firefox / WebKit対応が必要になった場合は、ブラウザ互換性上の必要性とCIコストを確認したうえで追加する。
* 初期段階から全ブラウザの組み合わせを必須化しない。

### D6. 本番Stimulus Controllerをテスト対象として直接利用する

* テスト専用にStimulus Controllerのロジックを複製しない。
* JavaScriptテストでは、本番で使用しているControllerを直接importして検証する。
* npm側で利用するStimulusは、本番Importmap側で利用するStimulusと互換する構成を維持する。
* npm版StimulusとImportmap版Stimulusの差異によって、テスト専用の挙動が成立する状態を許容しない。
* Stimulusの具体的なバージョン固定方法は実装Issueで決定する。

### D7. JavaScriptとRSpecの責務境界を固定する

テスト層の基本責務を以下に分離する。

#### Vitest + jsdom

* Stimulus Controllerの判断ロジック
* DOM状態変更
* JavaScript内部で完結するイベント処理
* ブラウザネイティブ保証を必要としない振る舞い

#### Vitest Browser Mode + Playwright

* 実ブラウザでなければ保証できないJavaScript挙動
* 実際のフォーカス遷移
* キーボード入力
* event propagation
* スクロール
* Browser API
* jsdomとの差異が問題になる挙動

#### RSpec Request Spec

* HTTPリクエスト / レスポンス契約
* HTTP status
* 認証・認可
* パラメータ不正時のサーバー側エラー
* Controller / Serviceへ渡るサーバー側入力境界
* JavaScriptを無効化しても成立すべきサーバー契約
* JavaScript実行を必要としない、サーバー側で生成されるHTML契約
* Turbo Frame構造、`data-*`、`aria-*`、初期選択状態等のサーバー生成値

JavaScript実行後に変更されるDOM状態、`data-*`、`aria-*`等については、Request Specだけで保証済みとはみなさない。

#### RSpec Model / Service Spec

* 業務ロジック
* DB整合性
* validation
* serviceの結果契約
* JavaScriptやブラウザを必要としないドメインロジック

#### RSpec System Spec

* Rails、DB、Turbo、JavaScriptを横断して初めて保証できる主要ユーザーフロー
* 複数の層が連携して成立するE2E契約
* ユーザー操作からサーバー更新、再描画までを含む主要導線
* Turboによる画面遷移・復元等、個別Controllerの単体テストだけでは保証できない統合挙動

System SpecをJavaScript Controllerの内部仕様を網羅するための代替テスト層として使用しない。

また、ある挙動をJavaScript単体で処理できることと、その挙動を含む実際のユーザーフロー全体が成立することは異なる保証として扱う。

### D8. 既存System Specそのものを負債とはみなさない

* 既存System Specの存在や件数そのものを、技術的負債とは定義しない。
* 本ADRでいう債務は、保証内容が本ADRで定めた責務境界と一致していない状態を指す。
* 例えば、Stimulus Controller単体で保証できる詳細挙動だけをSystem Specで保証している場合、その保証配置を再検討対象とする。
* System Specとして妥当なE2E保証は、JavaScriptテスト基盤導入後も維持する。
* System Spec件数の削減を成果指標にしない。

### D9. 既存System Specは同等保証成立後にのみ縮小・削除する

* 既存System Specの保証を別テスト層へ移行する場合、移行先で同等の保証が成立していることを先に確認する。
* 本ADRにおける「同等保証」とは、同じコードを通過することではなく、移行元が保証していた同一の契約または故障モードを移行先でも検出できる状態を指す。
* 移行先テストが存在しない状態で、既存System Specを先に削除しない。
* 1つのSystem Spec内に複数責務が存在する場合、移行対象となる保証だけを分離・縮小してよい。
* E2Eとして残すべき保証までまとめて削除しない。
* 下位テスト層で詳細挙動を保証し、System Specでその挙動を含む主要ユーザーフローを保証する場合、保証対象が異なるため、それだけを理由に不必要な重複とはみなさない。
* 同一の詳細契約または同一の故障モードを複数のテスト層で重複して網羅している場合は、責務境界に従って適切な層へ集約する。
* 既存System Specの具体的な棚卸し、移行先判定、縮小および削除は実装Issueで扱う。

### D10. ローカルとCIのJavaScriptテスト実行環境を可能な限り一致させる

* JavaScriptテストは、ローカルとCIで同じテストコードおよび同じ基本実行経路を使用する。
* ローカルだけ通りCIだけ失敗する環境差を増やさない。
* 実ブラウザテストに必要なChromium / Playwright等の依存も、再現可能なテスト環境として管理する。
* JavaScriptテストのためだけに本番Renderイメージへ不要なブラウザ依存を常設することは前提としない。
* Docker image、test用build target、Compose構成等の具体的な環境分離方法は実装Issueで決定する。

### D11. 具体的な導入・移行作業はIssue側で決定する

本ADRでは責務境界と採用方針を正本化し、以下の具体作業は実装Issueへ委譲する。

* Vitest / jsdom / Playwright等の具体的なバージョン
* `package.json`およびlockfileの構成
* Vitest設定ファイル
* Browser Mode設定
* Playwright / Chromiumのインストール方法
* Docker上のJavaScriptテスト環境
* CI workflowへの具体的な組み込み
* npm script
* テストファイルの配置規則
* 既存System Specの棚卸し
* 各既存保証の移行先判定
* System Specの具体的な縮小・削除
* 移行作業の順序

実装Issueは以下の2件に分ける。

1. JavaScriptテスト基盤導入
2. 既存System Specの責務再配置

JavaScriptテスト基盤を先に成立させ、その後に既存System Specの責務再配置を行う。

## Consequences

* 本番のImportmap構成を変更せずに、JavaScript専用テストを導入できる。
* Stimulus Controllerの詳細挙動をRSpec System Specだけに依存せず、より小さいテスト単位で保証できる。
* jsdomと実ブラウザの責務を分離することで、ブラウザを必要としないテストまで実ブラウザ化することを避けられる。
* focus、キーボード入力、event propagation、scroll、Browser API等の実ブラウザ挙動をBrowser Modeへ配置できる。
* 実ブラウザ保証をVitest Browser Modeへ集約するため、初期段階で独立したPlaywright Testとの二重管理を避けられる。
* Chromiumを必須ベースラインに限定するため、Firefox / WebKitを含む全ブラウザテストよりCI負荷を抑えられる。
* Request Spec、Model / Service Spec、JavaScriptテスト、System Specの責務境界が明確になる。
* サーバー生成HTMLとJavaScript実行後のDOM状態を分離して保証できる。
* 既存System Specを一律に削減しないため、E2E保証を失うことなく段階的に責務を再配置できる。
* 同じコードを通ることではなく、契約・故障モードを基準として同等保証を判断できる。
* 本番Controllerを直接テストするため、テスト専用ロジックとの乖離を避けられる。
* Node.js / npmという新しい開発依存は増える。
* Importmap側とnpm側のStimulus互換性を維持する必要が生じる。
* Browser Mode用にChromium / Playwrightを扱うため、JavaScriptテスト環境のDocker / CI構成が増える。
* 既存System Specの責務再配置は別Issueとなるため、JavaScriptテスト基盤導入だけではテスト構成の整理は完了しない。

## Out of Scope

本ADRでは以下を扱わない。

* 本番JavaScript配信方式をImportmapからbundlerへ移行すること
* Vite等を本番asset pipelineとして導入すること
* 独立したPlaywright Test基盤の導入
* Firefox / WebKitを初期必須ブラウザとすること
* JavaScriptライブラリの具体的なバージョン固定
* npm scriptの具体的な名称
* Vitest設定ファイルの具体的な内容
* Dockerfile / Compose / CI workflowの具体的な変更内容
* 個別Stimulus Controllerのテストケース設計
* 既存System Specの具体的な削除対象決定
* System Spec件数の削減目標
* 既存System Specの全面的な書き直し
* RSpec全体の再編
* アプリケーション機能そのものの仕様変更
* モーダル等の個別機能実装

## Related

* ADR-0009：ADR運用ルール（正本化・参照境界・改訂手順）
* ADR-0017：Asset.kind
* ADR-0019：Session一覧・Session詳細統合画面の表示・状態遷移・取得契約
