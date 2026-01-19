class AssetsController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize Asset, :index?
    @assets = policy_scope(Asset).with_attached_file.order(created_at: :desc)
  end


  def show
    @asset = policy_scope(Asset).with_attached_file.find(params[:id])
    authorize(@asset)
  end

  def new
    @asset = Asset.new(user: current_user)
    authorize(@asset)
  end

  def create
    @asset = Asset.new(user: current_user)
    authorize(@asset)

    files = Array(params.dig(:asset, :files)).reject(&:blank?)
    if files.empty?
      log_rejection(:no_files)
      @error_message = "ファイルが選択されていません。"
      return render(:new, status: :unprocessable_entity)
    end

    if files.size > Assets::UploadValidator::MAX_FILES_PER_UPLOAD
      log_rejection(:too_many_files, count: files.size)
      @error_message = "ファイル数が上限を超えています。"
      return render(:new, status: :unprocessable_entity)
    end

    result = Assets::BulkCreate.call(user: current_user, files: files)
    if result.success?
      redirect_to assets_path, notice: "#{result.assets.count}件の素材をアップロードしました。"
    else
      @error_message = error_message_for(result.error)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @asset = policy_scope(Asset).find(params[:id])
    authorize(@asset)
  end

  def update
    @asset = policy_scope(Asset).find(params[:id])
    authorize(@asset)

    display_name = params.dig(:asset, :display_name).presence || @asset.original_filename
    if @asset.update(display_name: display_name)
      redirect_to asset_path(@asset), notice: "名称を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @asset = policy_scope(Asset).find(params[:id])
    authorize(@asset)
    @asset.destroy!
    redirect_to assets_path, notice: "素材を削除しました。"
  end

  private

  def error_message_for(reason)
    case reason
    when :invalid_content_type
      "許可されていない形式です。"
    when :file_too_large
      "ファイルサイズが上限を超えています。"
    when :total_bytes_over_limit
      "合計サイズが上限を超えています。"
    when :total_capacity_exceeded
      "総容量が上限を超えています。"
    when :record_invalid
      "保存に失敗しました。"
    else
      "アップロードに失敗しました。"
    end
  end

  def log_rejection(reason, details = {})
    Rails.logger.info({ event: "asset_upload_rejected", reason: reason, **details })
  end

end
