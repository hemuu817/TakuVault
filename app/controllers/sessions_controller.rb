class SessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_session, only: %i[show edit update destroy]

  def index
    authorize Session, :index?
    @sessions = session_list_scope
  end

  def show
    authorize @session
    @sessions = session_list_scope
    @asset_grid = Sessions::AssetGridQuery.new(session: @session).call
  end

  def new
    @session = Session.new
    authorize @session
  end

  def create
    @session = current_user.sessions.build(session_params)
    authorize @session

    @session.save!

    redirect_to game_session_path(@session), notice: "セッションを作成しました。", status: :see_other
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def edit
    authorize @session
  end

  def update
    authorize @session
    if @session.update(session_params)
      redirect_to game_session_path(@session), notice: "セッションを更新しました。", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @session
    if @session.destroy
      redirect_to game_sessions_path, notice: "セッションを削除しました。", status: :see_other
    else
      redirect_to game_session_path(@session),
                  alert: "セッションを削除できませんでした。",
                  status: :see_other
    end
  end

  private

  def set_session
    @session = policy_scope(Session).find(params[:id])
  end

  def session_params
    params.require(:session).permit(:name, :room_url)
  end

  def session_list_scope
    policy_scope(Session).select(:id, :name, :created_at).order(created_at: :desc)
  end
end
