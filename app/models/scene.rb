class Scene < ApplicationRecord
  DEFAULT_POSITION = 1
  belongs_to :session

  validates :name, presence: true
  validates :position, presence: true,
                       numericality: { only_integer: true, greater_than: 0 }
  validate :default_position_is_immutable, on: :update

  before_destroy :default_scene_is_not_destroyable

  def default_scene?
    position == DEFAULT_POSITION
  end

  private

  def default_position_is_immutable
    return unless position_was == DEFAULT_POSITION && will_save_change_to_position?

    errors.add(:position, "はデフォルトシーンでは変更できません")
  end

  def default_scene_is_not_destroyable
    return unless default_scene?

    errors.add(:base, "デフォルトシーンは削除できません")
    throw :abort
  end

  def self.unique_position_violation?(error)
    message = error.message
    cause = error.cause

    message.include?("index_scenes_on_session_id_and_position") ||
      cause.is_a?(PG::UniqueViolation)
  end
  private_class_method :unique_position_violation?
end
