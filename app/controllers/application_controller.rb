class ApplicationController < ActionController::Base
  allow_browser versions: :modern, if: :authentication_required?
  before_action :authenticate_user!, if: :authentication_required?
  include Pundit::Authorization

  PUNDIT_EXCLUDED_CONTROLLERS = %w[rails/health rails/pwa].freeze
  PUNDIT_POLICY_SCOPED_ACTIONS = %w[index search uncategorized].freeze


  # -----------------------------------------------------------------------------
  # Pundit運用ルール（Issue #11で固定）
  #
  # 0) 対象/除外（例外管理はApplicationControllerに集約）
  #    - Devise は pundit_enabled? / authentication_required? 側で除外（controller側skip乱発禁止）
  #    - healthcheck/PWA等の例外は PUNDIT_EXCLUDED_CONTROLLERS で一元管理する
  #
  # 1) 認可方式の区分（index固定ではない）
  #    - コレクション系 action:
  #        policy_scope(Model) を必須
  #        対象 action は PUNDIT_POLICY_SCOPED_ACTIONS で一覧管理する
  #        例: index / search / uncategorized など
  #
  #    - メンバー系 action:
  #        authorize(record) を必須
  #        原則: PUNDIT_POLICY_SCOPED_ACTIONS に含まれない action はメンバー系として扱う（authorize必須）
  #
  # 2) 推奨実装パターン（安全な型を固定）
  #    - show/edit/update/destroy（既存レコード）:
  #        record = policy_scope(Model).find(params[:id])   # Model.find を先に呼ばない
  #        authorize(record)
  #
  #    - new/create（未保存レコード）: 【案A：レコード方式】に統一する
  #        record = Model.new(permitted_params)
  #        record.user = current_user                       # authorize より先にセット（重要）
  #        authorize(record)
  #
  #    ※ 理由:
  #      - #12（所有権強制）で record.user_id を Policy で参照する前提と整合させるため
  #      - user_id をセットせずに authorize すると誤判定（拒否/許可どちらも）を誘発し得る
  #
  # 3) 呼び忘れ検知（verify_*）は “枠だけ” 用意し、#11ではデフォルトOFF
  #    - pundit_verify_enabled? が false の間は verify_* は実行されない
  #    - #12（各Policy/Scope整備）と同一変更セットで true にして有効化する
  #    - 有効化後は、authorize/policy_scope の呼び忘れが開発ミス例外として顕在化する（意図通り）
  #
  # 4) 例外（意図的に認可を省略する分岐）
  #    - controller 単位で after_action を skip しない（skip_after_action 乱発禁止）
  #    - 例外が必要な場合のみ action 内で以下を使用する:
  #        skip_authorization / skip_policy_scope
  #    - 一時しのぎの回避目的で使わない（仕様として不要な場合に限定）
  #
  # 5) 未認可時の共通ハンドリング（404寄せの範囲を固定）
  #    - 404寄せは Pundit::NotAuthorizedError のみ（= 認可は実行され拒否されたケース）
  #    - 開発ミス検知例外は rescue しない（握りつぶさない）:
  #        Pundit::AuthorizationNotPerformedError（authorize呼び忘れ）
  #        Pundit::PolicyScopingNotPerformedError（policy_scope呼び忘れ）
  #        Pundit::NotDefinedError（Policy/Scope未定義）
  # -----------------------------------------------------------------------------


  # after_action は（前の話の通り）only/except を使わない形にするのが安全
  after_action :verify_authorized,
               if: -> { pundit_enabled? && pundit_verify_enabled? && !pundit_policy_scoped_action? }
  after_action :verify_policy_scoped,
               if: -> { pundit_enabled? && pundit_verify_enabled? && pundit_policy_scoped_action? }

  rescue_from Pundit::NotAuthorizedError, with: :render_not_found

  private

  def authentication_required?
    return false if devise_controller?
    true
  end

  def pundit_policy_scoped_action?
    PUNDIT_POLICY_SCOPED_ACTIONS.include?(action_name)
  end

  # NOTE: Devise以外は原則Pundit対象。Pundit不要なcontrollerを追加したら
  # 必ず PUNDIT_EXCLUDED_CONTROLLERS に追記すること（skip_after_action 乱発禁止）。
  def pundit_enabled?
    return false if devise_controller?
    !PUNDIT_EXCLUDED_CONTROLLERS.include?(controller_path)
  end

  def pundit_verify_enabled?
    false
  end

  def render_not_found
    head :not_found
  end
end
