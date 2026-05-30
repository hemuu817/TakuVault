class Scene < ApplicationRecord
  DEFAULT_POSITION = 1
  POSITION_RETRY_LIMIT = 3

  class PositionAssignmentFailed < StandardError; end

  belongs_to :session
  has_many :usages

  validates :name, presence: true
  validates :position, presence: true,
                       numericality: { only_integer: true, greater_than: 0 }
  validate :default_position_is_immutable, on: :update

  before_destroy :default_scene_is_not_destroyable

  def self.create_with_next_position!(session:, attributes:)
    retries = 0

    begin
      transaction(requires_new: true) do
        session.lock!
        next_position = session.scenes.maximum(:position).to_i + 1
        create_attributes = attributes.to_h.with_indifferent_access
        create_attributes[:name] = "scene#{next_position}" if create_attributes[:name].blank?

        session.scenes.create!(create_attributes.merge(position: next_position))
      end
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => error
      raise unless unique_position_violation?(error)

      retries += 1
      retry if retries < POSITION_RETRY_LIMIT

      raise PositionAssignmentFailed, error.message
    end
  end

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
