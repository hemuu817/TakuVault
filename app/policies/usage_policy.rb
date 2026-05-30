class UsagePolicy < ApplicationPolicy
  def create?
    true
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.joins(:asset).joins(scene: :session)
           .where(assets: { user_id: user.id }, sessions: { user_id: user.id })
    end
  end
end
