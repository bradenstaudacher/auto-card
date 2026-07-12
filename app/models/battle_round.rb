class BattleRound < ApplicationRecord
  STATUSES = %w[pending ready resolved].freeze

  belongs_to :game_session
  has_many :reward_offers, dependent: :destroy

  validates :round_number, presence: true
  validates :status, inclusion: { in: STATUSES }

  def resolved?
    status == "resolved"
  end

  def winner
    result_data&.dig("winner")
  end

  def victory?
    winner == "allies"
  end
end
