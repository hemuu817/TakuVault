class Usage < ApplicationRecord
  belongs_to :asset
  belongs_to :session
  belongs_to :scene

  enum :role, {
    background: 0,
    cutin: 1,
    bgm: 2,
    other: 3
  }

  scope :for_where_used, ->(user) {
    eager_load(:session, :scene)
      .where(sessions: { user_id: user.id })
      .order(Arel.sql("sessions.name ASC, scenes.position ASC, usages.role ASC"))
  }

  validates :role, presence: true

  def role_label
    self.class.role_label(role)
  end

  def self.role_label(role)
    I18n.t("activerecord.attributes.usage.roles.#{role}", locale: :ja)
  end
end
