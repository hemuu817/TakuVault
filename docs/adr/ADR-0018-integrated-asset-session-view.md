ADR-0018：素材一覧・Session管理統合画面の表示・状態遷移・遅延ロード契約

Status: Proposed

Context

TakuVaultでは、素材一覧とSession一覧が独立した画面になっており、Assetを確認する操作とSession / Scene / Usageを確認・管理する操作の間に画面往復が発生している。

素材一覧を主画面としてSession管理を統合するには、選択中Sessionの正本、URL、非同期更新範囲、連続切替時の競合制御、Scene配下Usageの遅延ロード、CRUD後の表示状態を一つの契約として固定する必要がある。

既存のADR-0010は、Issue #23とIssue #29が共有するrole / kind絞り込みを含む遅延ロード契約を定義していた。しかし、現方針では統合画面と絞り込みを分離し、Issue #23では検索・絞り込みを扱わないため、ADR-0010の前提と責務が一致しなくなった。

そのため、本ADRはADR-0010を置き換え、素材一覧・Session管理統合画面の表示、状態遷移、非同期更新、遅延ロードの契約を正本化する。

Decision

D1. 統合画面の責務

* 素材一覧をTakuVaultの主画面とし、同一画面内から以下を行える状態にする。
    * Asset一覧の確認
    * Sessionの選択
    * 選択Sessionの情報確認
    * 選択Session配下のScene確認
    * Scene配下Usageの確認
    * Session / Sceneの作成・編集・削除への遷移
* 統合画面は、既存の素材一覧を拡張して成立させる。
* 統合画面とは別に、同等のAsset一覧を持つdashboard画面は作成しない。
* Asset一覧はSession選択状態に依存せず表示する。
* Session詳細「セッション素材一覧」は既存画面として維持し、本ADRでは廃止・再設計しない。

D2. 統合画面の配置先

* 統合画面の配置先は、既存のAsset一覧画面とする。
* root routeは統合画面を指す状態を維持する。
* Asset一覧のURLは既存のAsset一覧URLを維持する。
* 選択Sessionは、Asset一覧URLのquery parameterで表現する。
    * 例：/assets?session_id=123
* 新しいdashboard専用routeは作成しない。

D3. 選択中Sessionの正本

* 選択中Sessionは、URLのsession_id query parameterを正本とする。
* session_idがない場合は、Session未選択状態とする。
* 有効なsession_idが指定されている場合は、当該Sessionを選択状態として表示を構築する。
* 選択中SessionをJavaScriptの変数、DOM、ブラウザキャッシュまたはサーバー側sessionだけで保持しない。
* JavaScript上の選択状態とURLが食い違う場合は、URLのsession_idを優先する。
* リロードおよびTurboキャッシュ復元後も、URLのsession_idから選択状態を再構築する。

D4. Session切替とブラウザ履歴

* 外部画面から統合画面へ遷移する操作は、通常の画面遷移としてブラウザ履歴へ追加する。
* 外部画面からsession_id付きの統合画面へ遷移する場合も、通常の画面遷移としてブラウザ履歴へ追加する。
* 統合画面内のSession選択操作では、ブラウザ履歴にSession選択履歴を追加しない。
* 統合画面内でSessionを切り替える場合は、現在の統合画面のURLをreplace相当で更新する。
* ブラウザバックは、統合画面内で過去に選択したSessionを順番に復元する用途には使用しない。
* ブラウザバックは、統合画面へ遷移する前の画面へ戻る操作として扱う。
* 実装に使用する具体的なHistory APIまたはTurbo APIは、実装Issueで決定する。

D5. Session件数増加への対応

* 初期の最大Session数が3件であっても、特定のSession件数だけを前提とする画面構造には固定しない。
* 将来、プランまたは追加オプションにより最大Session数が増える可能性を考慮し、最大30件程度までSessionを選択できる構造を妨げない。
* Session選択UIの具体形式は本ADRで固定しない。
    * タブ
    * <select>
    * コンボボックス
    * 検索可能なセレクタ
* すべてのSessionを横並びタブで表示することは、本ADRの前提にしない。
* Session選択肢の表示に必要な最小情報は取得してよい。
* 全Session配下のScene / Usage / Assetを統合画面の初期表示で取得しない。
* プラン別上限、追加オプション、課金、上限到達時の作成制御、プランダウン時の扱いは本ADRの対象外とする。

D6. Session未選択時とSessionなし状態

* session_idが指定されていない場合は、Session未選択状態を表示する。
* Sessionが存在していても、先頭Sessionを自動選択しない。
* Session未選択状態では、Asset一覧を維持したまま、Session選択を促す表示を行う。
* Sessionが0件の場合は、Asset一覧を維持したまま、Sessionが存在しないこととSession作成への導線を表示する。
* 他ユーザーのSession、削除済みSessionまたは存在しないSessionをsession_idに指定した場合は、404相当とする。
* 不正なsession_idを、Session未選択状態へ暗黙に読み替えない。

D7. 非同期更新の境界

統合画面は、次の表示領域に分ける。

1. Asset一覧領域
2. Session選択・管理領域
3. 選択Session領域
4. Scene配下Usage領域

* Asset一覧領域は、Session切替時に再取得・再描画しない。
* Session選択・管理領域には、Sessionの選択とSession CRUDへの導線を表示する。
* 選択Session領域には、選択したSessionの情報とSceneの骨格一覧を表示する。
* Session切替時は、選択Session領域を非同期で更新する。
* Scene配下Usage領域はScene単位で独立させ、Scene展開時に遅延ロードする。
* Session切替時に、全Scene配下のUsageを一括取得しない。

D8. Session切替時の状態遷移と競合制御

* Sessionが選択された時点で、直前SessionのScene / Usageを現在の選択Sessionの情報として表示し続けない。
* Session切替開始時は、選択Session領域をloading状態または未取得状態へ切り替える。
* Session切替要求が複数競合した場合は、最終的に選択されたSessionに対応する応答だけを画面へ反映する。
* 最終選択Sessionより前に開始された非同期応答は、完了順にかかわらず画面へ反映しない。
* 古い応答の適用防止は、以下のいずれかの方法で実装してよい。
    * 進行中requestの中断
    * request識別子による応答破棄
    * 応答適用時の選択Session再確認
    * 利用するTurbo機構が保証する最新navigationの採用
* 具体的な競合制御方法は実装Issueで決定するが、「最終選択が勝つ」という結果契約は変更しない。

D9. Scene骨格とUsage遅延ロード

* Session切替時に取得するのは、選択Sessionの情報とSceneの骨格一覧までとする。
* Sceneの骨格には、少なくとも以下を表示する。
    * Scene名
    * position
    * Scene管理への導線
    * Usage展開領域
* Sceneはposition昇順で表示する。
* default_sceneはADR-0001に従い、position=1として先頭に表示する。
* Scene配下Usageは、当該SceneのUsage表示が必要になった時点で取得する。
* 遅延ロードの取得単位は、Scene配下のUsage一覧とする。
* 遅延ロードの葉は、Asset単位ではなくUsageとする。
* 同一Assetに複数のUsageが存在する場合は、それぞれのUsageを表示する。
* Asset単位でdistinctしてUsageを重複排除しない。

D10. Usage遅延ロードのRequest / Response契約

* Usage遅延ロードの入力は、以下に固定する。
    * session_id
    * scene_id
* roleは遅延ロードの入力に含めない。
* kindは遅延ロードの入力に含めない。
* 検索・role絞り込み・kind絞り込み・Session絞り込みは、本ADRの対象外とする。
* 閲覧系の遅延ロードrouteは、SessionとSceneの親子関係を表現できるネストrouteとする。
    * 例：GET /sessions/:session_id/scenes/:scene_id/usages
* Usage作成routeは本ADRの対象外とし、ADR-0006に従いフラットなPOST /usagesを維持する。
* Responseは、サーバー側でレンダリングしたHTMLとする。
* SceneのUsage表示領域を、Turbo Frame等で差し替えられる形式とする。
* JSON APIとクライアント側テンプレートによる描画は採用しない。
* partial名、locals名、controller名、action名、Turbo Frame IDは実装Issueで決定し、本ADRでは固定しない。

D11. Usageの表示と表示順

* Scene配下Usageは、Usage.roleごとにグルーピングして表示する。
* Usageが存在するroleの見出しだけを表示する。
* Usageが0件のroleについて、空のrole見出しを表示しない。
* roleの表示順は、ADR-0016で定義されたUsage::DISPLAY_ROLE_ORDERに従う。
* 同一Sceneかつ同一role内のUsageは、以下の順序で表示する。
    1. usages.created_at昇順
    2. 同一created_atの場合はusages.id昇順
* Usageに表示するAssetタイルから、既存のAsset詳細へ直接遷移できるようにする。
* Asset詳細への遷移で、Asset編集画面を経由させない。
* Asset詳細のモーダル化は本ADRの対象外とする。

D12. 空状態と通信失敗

* Assetが0件の場合は、Assetが存在しないこととアップロードへの導線を表示する。
* Sessionが0件の場合は、Sessionが存在しないこととSession作成への導線を表示する。
* Session未選択時は、Sessionを選択するための案内を表示する。
* Scene配下のUsageが0件の場合は、エラーではなく空状態を表現するHTMLを200で返す。
* Scene一覧が0件の場合でも画面を破綻させない。
* Scene一覧が0件の状態は、default_sceneの不変条件に反する可能性があるため、通常のUsage空状態とは区別する。
* Scene一覧が0件だった場合は、Sceneが表示できない状態を画面へ表示し、通常のUsage 0件として暗黙に扱わない。
* 非同期通信に失敗した場合は、対象となる選択Session領域またはScene配下Usage領域にエラー状態を表示する。
* 通信失敗時に、直前Sessionまたは直前取得済みSceneの情報を現在の選択対象として表示し続けない。
* 通信失敗の影響を受けないAsset一覧領域は維持する。
* 通信失敗時は、対象領域を再取得できる導線を提供する。

D13. Session / Scene CRUD後の状態

Session作成後

* 統合画面へ遷移する。
* 作成したSessionを選択状態にする。
* URLのsession_idには、作成したSessionのIDを反映する。
* 作成時に生成されたdefault_sceneをScene一覧へ反映する。

Session編集後

* 編集対象Sessionを選択した統合画面へ遷移する。
* Sessionの選択状態を維持する。
* 編集後の名称、room_urlその他の表示情報を統合画面へ反映する。

Session削除後

* 削除対象Sessionが選択中だった場合は、Session未選択状態へ遷移する。
* URLから削除済みSessionのsession_idを除去する。
* 削除後に別のSessionを自動選択しない。
* 削除済みSessionのSceneおよび遅延ロード済みUsageを画面に残さない。

Scene作成後

* 親Sessionの選択状態を維持する。
* 作成したSceneを親Session配下のScene一覧へ反映する。
* Scene一覧はposition昇順で再構築する。

Scene編集後

* 親Sessionの選択状態を維持する。
* 編集後のScene名とpositionをScene一覧へ反映する。
* position変更後はScene一覧をposition昇順で再構築する。

Scene削除後

* 親Sessionの選択状態を維持する。
* 削除済みSceneと、そのSceneに対して遅延ロード済みのUsage表示を画面から除去する。
* default_sceneの削除不可はADR-0001に従う。
* Session / Scene CRUDのフォームをモーダル、インラインまたは独立画面のいずれで表示するかは、本ADRでは固定しない。
* 本ADRはCRUD操作後の遷移先と選択状態を正本とする。

D14. 既存Session画面の扱い

* 独立したSession一覧は、通常のナビゲーション導線から廃止する。
* 独立したSession一覧と統合画面を、二つの主要導線として併存させない。
* 既存の/sessionsへのアクセスは、独立した一覧を表示せず、統合画面へリダイレクトする。
* /sessionsから統合画面へリダイレクトする場合は、Session未選択状態とする。
* Session詳細画面は維持する。
* Session詳細「セッション素材一覧」は維持する。
* Sessionのnew / create / edit / update / destroyに必要な既存routeは維持する。
* Sceneのnew / create / edit / update / destroyに必要な既存routeは維持する。
* Session詳細画面を統合画面へ統合または廃止することは、本ADRの対象外とする。

D15. 認可境界

* Asset、Session、Scene、Usageの取得は、ADR-0007に従いpolicy_scopeを起点とする。
* 統合画面のAsset一覧は、policy_scope(Asset)から取得する。
* 選択Sessionは、policy_scope(Session)から取得し、取得後に閲覧権限をauthorizeする。
* Sceneは、認可済みSession配下かつpolicy_scope(Scene)の範囲から取得する。
* Scene単体の遅延ロードでは、取得したSceneに閲覧権限をauthorizeする。
* Usageは、認可済みSessionとSceneを条件に、policy_scope(Usage)から取得する。
* SessionとSceneの親子関係が一致しない場合は404相当とする。
* 他ユーザーのSession、Scene、UsageまたはAssetは表示しない。
* 他ユーザーの資源を指定した場合は、資源の存在を推測できない404相当とする。
* 認可済みのAssetからのみAsset詳細URLおよびActive Storageの参照URLを生成する。
* Usageから関連Assetへ到達できることだけを理由に、認可確認なしでAsset URLを生成しない。

D16. Turboキャッシュと画面復元

* Turboキャッシュ復元後は、URLのsession_idとSession選択UIの値を一致させる。
* Turboキャッシュ復元後は、URLのsession_idと選択Session領域の内容を一致させる。
* loading状態、通信失敗前の一時状態または削除済みSession / Sceneの表示を、正しい状態としてキャッシュへ残さない。
* Sceneの展開状態は、ブラウザバックまたはTurboキャッシュ復元後の維持を保証しない。
* 復元後にScene配下Usageが必要な場合は、再度遅延ロードしてよい。
* Scene展開状態の永続保存は本ADRの対象外とする。

D17. 取得境界とN+1防止

* 統合画面の初期表示で、全Session配下のScene / Usage / Assetを取得しない。
* Asset一覧は、表示に必要なActive Storage関連を事前読み込みする。
* Session切替時は、選択SessionとScene骨格の表示に必要な関連だけを取得する。
* Scene展開時は、当該Scene配下のUsage、Assetおよび表示に必要なActive Storage関連をまとめて取得する。
* 一回のScene遅延ロードrequest内で、Usage件数またはAsset件数に比例したqueryを発生させない。
* Sceneごとに独立した遅延ロードrequestが発生することは許容する。
* 具体的なincludes、preload、with_attached_*の指定は実装Issueで決定する。

D18. 旧ADRと絞り込み機能の扱い

* 本ADRはADR-0010を置き換える。
* 本ADRがAcceptedになった後、ADR-0010のStatusをSupersededへ変更し、本ADRへの参照を追記する。
* ADR-0010の本文は判断履歴として残し、削除しない。
* ADR-0010が定義していた以下の契約は、本ADRへ引き継がない。
    * roleを遅延ロードの任意入力とする契約
    * role不正時に400を返す契約
    * role変更時に展開済みSceneを再取得する契約
    * 絞り込みのためにAsset.kind判別情報を出力へ含める契約
    * Issue #23とIssue #29の共通契約
* 将来、role / kind / Sessionによる絞り込みを実装する場合は、本ADRを無条件に拡張せず、対象Issueと必要な設計判断を別途確認する。

Consequences

* 素材一覧を中心としてAsset・Session・Scene・Usageを同一画面から確認できるため、独立した素材一覧とSession一覧を往復する必要がなくなる。
* 選択SessionをURLで表現するため、リロード、直接URL、Turboキャッシュ復元時の状態をサーバー側で再構築できる。
* 統合画面内のSession切替でブラウザ履歴を追加しないため、切替回数やSession登録数が増えても、ブラウザバックがSession選択履歴で埋まらない。
* ブラウザバックでは直前に選択したSessionへ戻れないが、Session切替は独立ページへの遷移ではなく、統合画面内の表示対象変更として扱う。
* 初期のSession上限3件に限定したタブ構造へ固定しないため、将来最大Session数が増えた場合も、Session選択UIを置換できる。
* Asset一覧と選択Session領域を分離するため、Session切替ごとにAsset一覧を再取得する必要がない。
* Session切替時にScene骨格までを取得し、UsageをScene単位で遅延ロードするため、全UsageとActive Storage参照を一括取得する負荷を避けられる。
* Sceneごとに追加requestが発生するため、複数Sceneをすべて展開する場合はrequest数が増える。
* サーバーレンダリングHTMLへ固定するため、Railsの既存viewと認可済みURL生成を再利用しやすい。
* 将来JSON APIまたはクライアント側描画へ変更する場合は、Response契約の見直しが必要になる。
* 独立した/sessions一覧を統合画面へリダイレクトするため、Session一覧を前提とする既存導線とspecは更新が必要になる。
* Session詳細「セッション素材一覧」は維持されるため、既存のSession単位俯瞰画面は引き続き利用できる。
* Issue #29の絞り込みはADR-0010の共通契約から分離されるため、実装時に現在の画面構造に合わせて改めて設計する必要がある。
* 本ADRは表示・状態遷移・閲覧系取得契約を扱う。Usage作成・重複・所有権混在の扱いはADR-0006を正本とする。
* default_sceneの定義と不変条件はADR-0001を正本とする。
* Usage.roleの許容値と表示順はADR-0016を正本とする。
* Session / Scene / Usage / AssetのDB構造は変更しない。

Supersedes

* ADR-0010：Where used ツリー遅延ロード契約（Session/Scene/Usage）

Related

* ADR-0001：default_scene（position=1固定・削除不可）
* ADR-0006：Usage割当ルール（未整理一括割当・冪等・所有権整合）
* ADR-0007：所有権の正本と混在禁止
* ADR-0009：ADR運用ルール（正本化・参照境界・改訂手順）
* ADR-0010：Where used ツリー遅延ロード契約（Session/Scene/Usage）
* ADR-0016：Session詳細「セッション素材一覧」表示仕様
* Issue #23：素材一覧とSession管理の統合
* Issue #29：絞り込み（kind / role / Session）
* Issue #68：Asset詳細のモーダル化
* Issue #136：Session詳細「セッション素材一覧」
