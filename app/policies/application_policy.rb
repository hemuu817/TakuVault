class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    # Closed system（ログイン必須アプリ）では、未ログインが Policy に到達した時点で例外にして
    # 「authenticate_user! の付け忘れ」等を早期に発見できるようにする。
    raise Pundit::NotAuthorizedError, "must be logged in" unless user

    @user = user
    @record = record
  end

  # --- default: fail-closed (deny-all) ---
  # 個別 Policy（例: AssetPolicy）で明示的に許可したものだけを通す。
  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  private

  # 共通ヘルパ（任意）
  # 「所有者のみ許可」を書く頻度が高いなら、ここに寄せると重複が減る。
  # record が user_id を持たないモデルなら false になり、許可に倒れない（fail-closed）。
  def owner?
    record.respond_to?(:user_id) && record.user_id == user.id
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      # Policy と同様に、未ログインが Scope に到達した時点で明示的に失敗させる。
      raise Pundit::NotAuthorizedError, "must be logged in" unless user

      @user = user
      @scope = scope
    end

    def resolve
      # 元の `scope.none` は安全だが、「Scope 実装漏れ」が "0件表示" として見えて発見が遅れる。
      # そこで開発/テストでは NotImplementedError を出して即気づけるようにする。
      if Rails.env.production?
        scope.none
      else
        raise NotImplementedError, "#{self.class.name}#resolve must be implemented in each policy"
      end
    end
  end
end
