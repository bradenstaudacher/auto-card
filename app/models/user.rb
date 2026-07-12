class User < ApplicationRecord
  has_many :players, dependent: :destroy
  has_many :game_sessions, through: :players

  validates :handle, presence: true
end
