class Session < ApplicationRecord
  belongs_to :user
  has_many :scenes, dependent: :destroy, inverse_of: :session

  validates :name, presence: true
  validate :room_url_scheme, if: -> { room_url.present? }

  private

  def room_url_scheme
    uri = URI.parse(room_url)
    errors.add(:room_url, :invalid_scheme) unless %w[http https].include?(uri.scheme)
  rescue URI::InvalidURIError
    errors.add(:room_url, :invalid)
  end
end
