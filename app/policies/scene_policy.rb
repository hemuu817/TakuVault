class ScenePolicy < ApplicationPolicy
  def index?   = true
  def show?    = owner?
  def new?     = create?
  def create?  = owner?
  def edit?    = update?
  def update?  = owner?
  def destroy? = owner? && !record.default_scene?

  private

  def owner?
    record.session.user_id == user.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.joins(:session).where(sessions: { user_id: user.id })
    end
  end
end
