class UsagesController < ApplicationController
  before_action :authenticate_user!

  def create
    authorize Usage, :create?

    result = if params[:usage_mode] == "bulk"
      Usages::BulkCreateService.call(
        user: current_user,
        asset_ids: params[:asset_ids],
        session_id: params[:session_id],
        scene_id: params[:scene_id],
        role: params[:role]
      )
    else
      Usages::CreateService.call(
        user: current_user,
        asset_id: params[:asset_id],
        session_id: params[:session_id],
        scene_id: params[:scene_id],
        role: params[:role]
      )
    end

    if result.success?
      redirect_to success_redirect_path,
                  notice: success_message(result),
                  status: :see_other
    else
      render plain: error_message_for(result.error), status: result.status
    end
  end

  def update
    usage = policy_scope(Usage).find(params[:id])
    authorize usage

    result = Usages::UpdateService.call(
      user: current_user,
      usage: usage,
      scene_id: params[:scene_id],
      role: params[:role]
    )

    if result.success?
      redirect_to asset_path(result.usage.asset),
                  notice: "Usageを更新しました。",
                  status: :see_other
    else
      render plain: error_message_for(result.error), status: result.status
    end
  end

  private

  def success_redirect_path
    params[:asset_id].present? ? asset_path(params[:asset_id]) : uncategorized_assets_path
  end

  def success_message(result)
    return "Usageを追加しました。" unless result.respond_to?(:created_count)

    message = "Usageを作成しました（作成#{result.created_count}件 / 重複スキップ#{result.skipped_duplicate_count}件）。"
    return message if result.skipped_assets.blank?

    skipped_names = result.skipped_assets.map { |asset| asset[:display_name] }.join(", ")
    "#{message} スキップ: #{skipped_names}"
  end

  def error_message_for(error)
    case error
    when :invalid_role
      "roleが不正です。"
    when :duplicate
      "同じUsageが既に存在します。"
    when :asset_required
      "素材を選択してください。"
    else
      "Usageを作成できませんでした。"
    end
  end
end
