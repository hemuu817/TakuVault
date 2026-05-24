class SessionPolicy < ApplicationPolicy
  def index?   = true
  def show?    = owner?
  def new?     = create?
  def create?  = record.user_id.nil? || record.user_id == user.id
  def edit?    = update?
  def update?  = owner?
  def destroy? = owner?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user_id: user.id)
    end
  end
end
