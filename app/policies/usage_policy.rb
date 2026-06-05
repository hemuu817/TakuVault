class UsagePolicy < ApplicationPolicy
  def create?
    true
  end

  def update?
    record.asset.user_id == user.id && record.session.user_id == user.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.joins(:asset).joins(scene: :session)
           .where(assets: { user_id: user.id }, sessions: { user_id: user.id })
    end
  end
end
