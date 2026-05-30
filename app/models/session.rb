class Session < ApplicationRecord
  belongs_to :user
  has_many :scenes, inverse_of: :session
  has_many :usages

  after_create :create_default_scene!

  validates :name, presence: true
  validate :room_url_scheme, if: -> { room_url.present? }

  private

  def create_default_scene!
    scenes.create!(position: Scene::DEFAULT_POSITION, name: "scene1")
  end

  def room_url_scheme
    uri = URI.parse(room_url)
    errors.add(:room_url, :invalid_scheme) unless %w[http https].include?(uri.scheme)
  rescue URI::InvalidURIError
    errors.add(:room_url, :invalid)
  end
end
