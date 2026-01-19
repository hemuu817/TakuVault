# app/policies/asset_policy.rb
class AssetPolicy < ApplicationPolicy
  # ApplicationPolicy で「未ログインは例外」にしている前提なので、
  # ここでは user.present? の分岐は基本不要（= ロジックを単純化できる）。

  def index?
    true
  end

  def show?
    owner?
  end

  def new?
    create?
  end

  # 作成は「ログインしているユーザーなら許可」。
  # owner? を使うと、新規作成時点では record.user_id が未設定になりやすく、
  # 正当なユーザーでも create? が false になってしまう。
  def create?
    # 追加の安全弁：
    # もしコントローラ側で誤って user_id を別ユーザーにセットしてしまった場合でも弾ける。
    record.user_id.nil? || record.user_id == user.id
  end

  def edit?
    update?
  end

  def update?
    owner?
  end

  def destroy?
    owner?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user_id: user.id)
    end
  end
end
