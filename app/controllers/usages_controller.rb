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
                  notice: t("usages.update.success", locale: :ja),
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
    return t("usages.create.success", locale: :ja) unless result.respond_to?(:created_count)

    message = t("usages.create.bulk_success",
                locale: :ja,
                created_count: result.created_count,
                skipped_duplicate_count: result.skipped_duplicate_count)
    return message if result.skipped_assets.blank?

    skipped_names = result.skipped_assets.map { |asset| asset[:display_name] }.join(", ")
    "#{message} #{t("usages.create.skipped_assets", locale: :ja, names: skipped_names)}"
  end

  def error_message_for(error)
    case error
    when :invalid_role
      t("usages.create.invalid_role", locale: :ja)
    when :duplicate
      t("usages.create.duplicate", locale: :ja)
    when :asset_required
      t("usages.create.asset_required", locale: :ja)
    else
      t("usages.create.failure", locale: :ja)
    end
  end
end
