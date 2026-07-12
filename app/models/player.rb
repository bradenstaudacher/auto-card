class Player < ApplicationRecord
  belongs_to :user
  belongs_to :game_session
  has_many :player_characters, dependent: :destroy
  has_many :player_cards, dependent: :destroy
  has_many :reward_offers, dependent: :destroy

  validates :seat, inclusion: { in: [1, 2] }

  def tableau
    player_cards.includes(:card_template)
  end
end
