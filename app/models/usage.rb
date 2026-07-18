class Usage < ApplicationRecord
  belongs_to :asset
  belongs_to :session
  belongs_to :scene

  enum :role, {
    background: 0,
    cutin: 1,
    bgm: 2,
    other: 3,
    standing: 4,
    panel: 5,
    sound_effect: 6
  }

  DISPLAY_ROLE_ORDER = %w[background standing cutin panel bgm sound_effect other].freeze

  ROLE_KIND_CANDIDATES = {
    "background" => %w[image],
    "standing" => %w[image],
    "cutin" => %w[image],
    "panel" => %w[image],
    "bgm" => %w[audio],
    "sound_effect" => %w[audio],
    "other" => %w[image audio other]
  }.transform_values(&:freeze).freeze

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
