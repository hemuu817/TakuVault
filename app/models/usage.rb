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

  validates :role, presence: true
end
