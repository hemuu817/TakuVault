class SessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_session, only: %i[show edit update destroy]

  def index
    authorize Session, :index?
    @sessions = policy_scope(Session).order(created_at: :desc)
  end

  def show
    authorize @session
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
    @session.destroy
    redirect_to game_sessions_path, notice: "セッションを削除しました。", status: :see_other
  end

  private

  def set_session
    @session = policy_scope(Session).find(params[:id])
  end

  def session_params
    params.require(:session).permit(:name, :room_url)
  end
end
