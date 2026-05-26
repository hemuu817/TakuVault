class ScenesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_session
  before_action :set_scene, only: %i[show edit update destroy]

  def index
    @scenes = policy_scope(@session.scenes).order(:position)
    authorize @session.scenes.build
  end

  def show
    authorize @scene
  end

  def new
    @scene = @session.scenes.build
    authorize @scene
  end

  def create
    @scene = @session.scenes.build(scene_params)
    authorize @scene
    @scene = Scene.create_with_next_position!(session: @session, attributes: scene_params)

    redirect_to game_session_path(@session), notice: "シーンを作成しました。", status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    @scene = error.record if error.record.is_a?(Scene)
    render :new, status: :unprocessable_entity
  rescue Scene::PositionAssignmentFailed
    @scene ||= @session.scenes.build(scene_params)
    @scene.errors.add(:base, "シーンの作成に失敗しました。もう一度実行してください。")
    render :new, status: :unprocessable_entity
  end

  def edit
    authorize @scene
  end

  def update
    authorize @scene
    if default_position_change_attempt?
      @scene.errors.add(:position, "はデフォルトシーンでは変更できません")
      render :edit, status: :unprocessable_entity
    elsif @scene.update(scene_params)
      redirect_to game_session_path(@session), notice: "シーンを更新しました。", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @scene
    if @scene.destroy
      redirect_to game_session_path(@session), notice: "シーンを削除しました。", status: :see_other
    else
      redirect_to game_session_path(@session), alert: @scene.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private

  def set_session
    @session = policy_scope(Session).find(params[:game_session_id])
  end

  def set_scene
    @scene = policy_scope(@session.scenes).find(params[:id])
  end

  def scene_params
    params.require(:scene).permit(:name)
  end

  def default_position_change_attempt?
    return false unless @scene.default_scene?
    return false unless params.require(:scene).key?(:position)

    params.require(:scene)[:position].to_i != Scene::DEFAULT_POSITION
  end
end
