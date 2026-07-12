class GameSession < ApplicationRecord
  MODES = %w[single_player two_player_coop].freeze
  STATUSES = %w[lobby preparation battle reward completed].freeze

  has_many :players, dependent: :destroy
  has_many :battle_rounds, dependent: :destroy

  validates :mode, inclusion: { in: MODES }
  validates :status, inclusion: { in: STATUSES }
  validates :seed, presence: true

  def single_player?
    mode == "single_player"
  end

  def coop?
    mode == "two_player_coop"
  end

  def current_battle_round
    battle_rounds.find_by(round_number: current_round)
  end

  def final_round?
    current_round >= max_rounds
  end
end
