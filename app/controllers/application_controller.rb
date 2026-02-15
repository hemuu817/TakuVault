class ApplicationController < ActionController::Base
  allow_browser versions: :modern, if: :authentication_required?
  before_action :authenticate_user!, if: :authentication_required?
  include Pundit::Authorization

  PUNDIT_EXCLUDED_CONTROLLERS = %w[rails/health rails/pwa].freeze
  PUNDIT_POLICY_SCOPED_ACTIONS = %w[index search uncategorized].freeze
  BOOLEAN_TYPE = ActiveModel::Type::Boolean.new

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
    return true if Rails.env.development? || Rails.env.test?
    BOOLEAN_TYPE.cast(ENV.fetch("PUNDIT_VERIFY", false))
  end

  def render_not_found
    head :not_found
  end
end
