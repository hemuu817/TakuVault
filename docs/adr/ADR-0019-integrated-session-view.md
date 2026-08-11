ADR-0019：Session一覧・Session詳細統合画面の表示・状態遷移・取得契約

Status: Proposed

Context

TakuVaultでは、Assetを起点に素材を探す操作と、Sessionを起点にScene・Usage・使用素材を確認する操作では、必要とされる閲覧軸が異なる。

ADR-0018では、素材一覧を主画面としてSession管理を同一画面へ統合し、独立したSession一覧を主要導線から廃止する方針を採用していた。しかし、素材一覧へSession管理を統合すると、Asset起点の素材管理とSession起点の構成管理が一つの画面へ集中し、それぞれの画面責務が不明確になる。

また、既存のSession詳細には、Session基本情報、Scene管理およびScene×用途の「セッション素材一覧」が存在する。これらは素材一覧へ移すのではなく、Session一覧とSession詳細を一つのSession起点画面として統合する方が、既存の閲覧軸と画面責務を維持できる。

そのため、本ADRはADR-0018を置き換え、素材一覧とSession画面を独立した主要画面として維持しながら、Session一覧とSession詳細を統合する画面構成、URL、状態遷移、更新境界、取得境界および認可境界を正本化する。

Decision

D1. 素材一覧とSession画面の責務

- 素材一覧は、Assetを起点として素材を確認・管理する独立した主要画面として維持する。
- Session画面は、Sessionを起点としてSession、Scene、Usageおよび使用素材を確認・管理する独立した主要画面として維持する。
- 素材一覧へSessionの選択・管理領域を統合しない。
- 素材一覧とSession統合画面を、異なる閲覧軸を持つ二つの主要画面として併存させる。
- Asset詳細は、Assetを起点としたWhere usedの表示責務を維持する。
- Session詳細は、選択Session内のSceneと使用素材を俯瞰する責務を維持する。
- root routeは、独立した素材一覧を指す状態を維持する。
- 新しいdashboard専用画面およびdashboard専用routeは作成しない。

D2. Session一覧とSession詳細の統合

- Session画面は、Session一覧とSession詳細を同一画面内へ統合する。
- 統合画面は、概念的に以下の二つの領域で構成する。
    - Session一覧・管理領域
    - 選択Sessionの詳細領域
- 基本レイアウトでは、Session一覧・管理領域を左側、選択Sessionの詳細領域を右側に配置する。
- Session一覧・管理領域は、概念的にSessionのindexの責務を持つ。
- 選択Sessionの詳細領域は、概念的にSessionのshowの責務を持つ。
- 狭い画面では配置方法を変更してよいが、Sessionの選択・管理および選択Sessionの詳細確認という責務は失わない。
- Session詳細だけを表示し、Session一覧を含まない別の主要画面は作成しない。

D3. URLと選択中Sessionの正本

- `/sessions`は、Session未選択状態の統合画面を表す。
- `/sessions/:id`は、対象Sessionが選択された状態の統合画面を表す。
- `/sessions/:id`へ直接アクセスした場合も、Session一覧・管理領域と選択Sessionの詳細領域を含む統合画面全体を表示する。
- `/sessions/:id`を、選択Sessionの詳細領域だけを返すURLとして扱わない。
- 選択中Sessionの正本はURLとする。
- 選択中Sessionを、JavaScript変数、DOM、Turboキャッシュまたはサーバー側sessionだけで保持しない。
- URLと画面上の選択状態が一致しない場合は、URLを優先する。
- Sessionが存在していても、`/sessions`へのアクセス時に先頭Sessionを自動選択しない。

D4. Session切替とブラウザ履歴

- 統合画面内でSessionの切替を開始した時点では、現在のURL、Session一覧上の選択表示およびSession詳細を維持する。
- Session切替が成功した時点で、URL、Session一覧上の選択表示およびSession詳細を、対象Sessionの状態へまとめて更新する。
- Session切替成功時のURLは、対象Sessionの`/sessions/:id`とする。
- 統合画面内でSessionを切り替えた場合、ブラウザ履歴へSession選択ごとの履歴を追加しない。
- Session切替成功時のURL更新は、現在の履歴を置き換える操作として扱う。
- ブラウザバックは、統合画面内で過去に選択したSessionを順番に復元する操作として扱わない。
- ブラウザバックは、統合画面へ遷移する前の画面へ戻る操作として扱う。
- URL更新に使用する具体的なブラウザAPIまたはTurboの機構は、本ADRでは固定しない。

D5. Session未選択状態、Sessionなし状態および不正なSession

- `/sessions`では、Session一覧・管理領域を表示し、Session詳細領域は未選択状態として表示する。
- Sessionが0件の場合は、Sessionが存在しないこととSession作成への導線を表示する。
- Sessionが存在していても、未選択状態を別のSession選択状態へ暗黙に変更しない。
- 存在しないSession、削除済みSessionまたは他ユーザーが所有するSessionを指定した場合は、404相当とする。
- 不正なSession IDを、Session未選択状態へ暗黙に読み替えない。

D6. Session件数増加への対応

- 特定のSession件数だけを前提とする画面構造には固定しない。
- 初期のSession上限が少数であっても、将来最大30件程度までSessionを選択できる構造を妨げない。
- Session一覧に必要な最小情報は取得してよい。
- 全Session配下のScene、UsageおよびAssetを、Session一覧の表示を目的として取得しない。
- Session件数増加に対応する検索、ページネーションまたは仮想表示は、本ADRでは固定しない。
- プラン別上限、課金、上限到達時の作成制御およびプランダウン時の扱いは、本ADRの対象外とする。

D7. Session切替時の更新境界

- Session切替時の更新単位は、Session一覧・管理領域と選択Sessionの詳細領域を含むSession領域全体とする。
- Session切替の成功時は、以下を同じ選択状態として整合させる。
    - URL
    - Session一覧上の選択表示
    - 選択Sessionの詳細
    - loading表示
    - エラー表示
- 共通ナビゲーションなど、Session領域外の表示はSession切替の更新対象に含めない。
- 選択Sessionの詳細領域だけを更新し、URLまたはSession一覧上の選択表示と不一致になる状態を許容しない。
- 更新に使用する具体的な部分更新機構は、本ADRでは固定しない。

D8. Session切替中、通信失敗および競合時の状態

- Session切替が成功するまでは、直前に正常表示されたSessionのURL、選択表示および詳細を維持する。
- Session切替中であることを画面上で識別できる状態にする。
- Session切替が成功した場合は、URL、Session一覧上の選択表示およびSession詳細を対象Sessionの状態へまとめて更新する。
- Session切替に失敗した場合は、直前に正常表示されたSessionのURL、選択表示および詳細を維持する。
- Session切替に失敗した場合は、エラー状態と再試行導線を表示する。
- `/sessions`の未選択状態から最初のSession選択に失敗した場合は、URLを`/sessions`のままとし、未選択状態を維持する。
- Session切替要求が複数競合した場合は、最後に選択されたSessionに対応する結果だけを画面へ反映する。
- 最後に選択されたSessionより前に開始された応答は、完了順にかかわらず画面へ反映しない。
- 古い応答を破棄する具体的な方法は、本ADRでは固定しない。

D9. Session一覧・管理領域と選択Sessionの詳細領域

Session一覧・管理領域

- Sessionの選択および切替を行える状態にする。
- 選択中Sessionを判別できる表示を持つ。
- Sessionの作成・編集・削除へ到達できる導線を持つ。
- Sessionを選択する操作と、Sessionを削除する操作を明確に分離する。
- Sessionの編集・削除導線を各Session行へ直接配置するか、操作メニューへ格納するかは、本ADRでは固定しない。
- Session削除導線をSession一覧・管理領域だけに配置するか、選択Sessionの詳細領域にも配置するかは、本ADRでは固定しない。

選択Sessionの詳細領域

- 選択Sessionの詳細領域には、以下を表示する。
    - Session基本情報
    - Session名
    - room_url
    - Session編集への導線
    - Scene一覧
    - Scene作成・編集・削除への導線
    - セッション素材一覧
    - Asset詳細への導線
- Sceneの作成・編集フォームおよびScene詳細は、Session統合画面内へインライン化しない。
- SessionまたはSceneの作成・編集フォームは、既存の独立画面への遷移を維持する。
- Asset詳細をSession統合画面内へインライン化またはモーダル化しない。
- 選択Sessionの詳細表示は、Session一覧と組み合わせて再利用できる表示責務へ分離する。
- 具体的なビュー分割方法は、本ADRでは固定しない。

D10. Scene、UsageおよびAssetの取得境界

- Session切替時は、選択された一つのSessionの詳細だけを取得する。
- 統合画面の初期表示またはSession切替時に、全Session配下のScene、UsageおよびAssetを一括取得しない。
- 選択Sessionについては、Session基本情報、Scene、Usageおよび表示対象Assetをまとめて取得する。
- Scene単位の遅延ロードは、本ADRでは採用しない。
- セッション素材一覧は、既存の行＝Scene、列＝用途の表示契約を維持する。
- Scene、用途およびセル内Assetの表示順は、ADR-0016を正本とする。
- default_sceneの表示位置と不変条件は、ADR-0001を正本とする。
- Assetタイルから、既存のAsset詳細へ遷移できる状態を維持する。
- 表示対象となるUsage、AssetおよびActive Storage関連の件数に比例して追加の問い合わせが発生しない取得境界を維持する。
- 他ユーザーが所有するAssetを表示対象に含めない。
- 具体的な関連取得方法は、本ADRでは固定しない。

D11. Session CRUD後の状態

Session作成後

- 作成したSessionの`/sessions/:id`へ遷移する。
- 作成したSessionを選択状態として表示する。
- Session一覧とSession詳細の両方へ作成結果を反映する。

Session編集後

- 編集対象Sessionの`/sessions/:id`へ遷移する。
- 編集対象Sessionの選択状態を維持する。
- Session一覧とSession詳細の両方へ編集結果を反映する。

選択中Sessionの削除後

- `/sessions`へ遷移する。
- Session詳細領域を未選択状態にする。
- 別のSessionを自動選択しない。
- 削除したSessionのScene、Usageおよび表示対象Assetを画面に残さない。

選択されていないSessionの削除後

- 現在選択中のSessionとURLを維持する。
- 現在表示中のSession詳細を維持する。
- Session一覧から削除対象Sessionだけを除去する。

Session削除失敗時

- Session一覧、選択中SessionおよびSession詳細を維持する。
- 削除に失敗したことを表示する。
- 削除導線の表示有無を認可の根拠にしない。

D12. Scene CRUD後の状態

- Scene作成・編集・削除後は、親Sessionの`/sessions/:id`へ遷移する。
- Scene CRUD後も、親Sessionの選択状態を維持する。
- Scene作成後は、作成したSceneをScene一覧とセッション素材一覧へ反映する。
- Scene編集後は、編集結果をScene一覧とセッション素材一覧へ反映する。
- Scene削除後は、削除したSceneとそのSceneに属するUsageを画面に残さない。
- Scene CRUD後は、Scene一覧とセッション素材一覧を既存の表示順に従って再構築する。
- default_sceneの削除不可およびposition不変条件は、ADR-0001を正本とする。

D13. Turboキャッシュと画面復元

- Turboキャッシュから復元した場合も、URLとSession一覧上の選択状態を一致させる。
- `/sessions`では、Session未選択状態を復元する。
- `/sessions/:id`では、URLで指定されたSessionの選択状態と詳細を復元する。
- URLとキャッシュ内容が一致しない場合は、URLを優先する。
- JavaScript変数またはDOMだけを根拠として、選択中Sessionを復元しない。
- loading中または通信失敗中の一時状態を、正常な表示状態としてキャッシュに残さない。
- 削除済みSessionまたは削除済みSceneの表示を、正常な状態として復元しない。

D14. 認可境界

- Session、Scene、UsageおよびAssetの所有権と認可境界は、ADR-0007を正本とする。
- Session一覧と選択Sessionは、ADR-0007に従い、認可されたSessionの範囲から取得する。
- Scene、UsageおよびAssetは、選択Sessionの認可境界を越えて取得しない。
- 他ユーザーが所有するSessionを指定した場合は、Sessionの存在を推測できない404相当とする。
- Session一覧上の編集・削除導線は操作入口であり、権限判定の正本にはしない。
- 所有権の伝播、混在禁止、取得起点および認可済みAssetからのURL生成に関する詳細は、ADR-0007を正本とする。

D15. 大量Sceneの扱い

- 本ADRでは、Session配下に作成できるScene件数のハード上限を追加しない。
- Scene件数にかかわらず、全件一括描画の性能を保証する契約は設けない。
- 大量Sceneへのpagination、仮想表示、Scene単位の遅延ロードまたは作成件数制限は、別の設計判断およびIssueで扱う。
- 本ADRでは、選択Sessionだけを取得対象とする境界、既存の表示順および関連件数に比例する追加問い合わせの防止を維持する。

D16. 旧ADRの扱い

- 本ADRはADR-0018を置き換える。
- 本ADRがAcceptedになった場合、ADR-0018のStatusをSupersededへ変更し、本ADRへの参照を追記する。
- ADR-0018の本文は判断履歴として残し、削除しない。
- ADR-0018が置き換えたADR-0010の履歴も維持する。
- ADR-0018が定義していた以下の契約は、本ADRへ引き継がない。
    - 素材一覧を主画面としてSession管理を統合する契約
    - `/assets?session_id=:id`で選択中Sessionを表現する契約
    - 独立したSession一覧を主要導線から廃止する契約
    - Scene配下UsageをScene単位で遅延ロードする契約
    - Session切替開始時に直前Sessionの詳細を未取得状態へ置き換える契約
- 検索、絞り込みおよびソートは、本ADRの対象外とする。

Consequences

- 素材一覧とSession統合画面を異なる閲覧軸として分離できるため、それぞれの画面責務が明確になる。
- root routeは素材一覧を指す状態を維持するため、既存の素材一覧への主要導線を変更せずにSession統合画面を追加できる。
- Session一覧とSession詳細を同一画面へ統合するため、Sessionを切り替えるたびに一覧と詳細を往復する必要がなくなる。
- `/sessions`と`/sessions/:id`で選択状態を表現するため、直接アクセス、リロードおよびTurboキャッシュ復元時に状態を再構築できる。
- Session切替が成功した時点でURLと画面をまとめて更新するため、URLと表示中Sessionの不一致を防止できる。
- Session切替ごとのブラウザ履歴を追加しないため、ブラウザバックがSession選択履歴で埋まらない。
- ブラウザバックでは、統合画面内で直前に選択していたSessionへ戻れない。
- Session切替時に直前の正常表示を維持するため、通信中または通信失敗時に詳細領域が空になることを避けられる。
- Session一覧とSession詳細を一つの更新単位として扱うため、URL、選択表示および詳細表示の不一致を防止できる。
- 特定のSession件数を前提としないため、将来Session上限が増加した場合も、Session選択UIを置き換えられる。
- Session一覧とSession詳細を同じ画面構造で扱うため、既存のSession一覧画面およびSession詳細画面を前提とする表示責務とテストの見直しが必要になる。
- 選択SessionのScene、UsageおよびAssetをまとめて取得するため、Scene単位の追加requestは発生しない。
- Scene件数またはUsage件数が多いSessionでは、一回の取得量と描画量が増加する。
- 大量Sceneへのpagination、仮想表示、遅延ロードまたは件数制限は別Issueとして検討する必要がある。
- 既存のセッション素材一覧を維持するため、Scene×用途の俯瞰表示とAsset詳細への遷移を引き続き利用できる。
- 素材一覧へSession管理を統合しないため、ADR-0018を前提としたIssueおよび実装案は利用できない。
- 本ADRは画面構成、状態遷移、取得境界および認可境界を扱う。具体的なビュー分割、部分更新機構、競合制御方法およびCSSは実装Issueで決定する。
- Session、Scene、UsageおよびAssetのデータモデルは変更しない。

Supersedes

- ADR-0018：素材一覧・Session管理統合画面の表示・状態遷移・遅延ロード契約

Related

- ADR-0001：default_scene（position=1固定・削除不可）
- ADR-0007：所有権の正本と混在禁止
- ADR-0009：ADR運用ルール（正本化・参照境界・改訂手順）
- ADR-0010：Where used ツリー遅延ロード契約（Session / Scene / Usage、Superseded）
- ADR-0016：Session詳細「セッション素材一覧」表示仕様
- ADR-0018：素材一覧・Session管理統合画面の表示・状態遷移・遅延ロード契約
- Issue #23：素材一覧とSession管理の統合（旧方針）
- Issue #174：（45）セッション画面の統合（作成後にGitHub Issue番号を追記）