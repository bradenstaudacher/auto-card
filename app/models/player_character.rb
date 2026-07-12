class PlayerCharacter < ApplicationRecord
  belongs_to :player
  belongs_to :champion_template
  has_many :player_cards, foreign_key: :assigned_to_player_character_id,
                          dependent: :nullify, inverse_of: false

  # current_stats defaults to the champion base stats when the character is
  # created; equipped cards mutate a working copy at battle-build time (M4).
  def effective_stats
    current_stats.presence || champion_template.base_stats
  end

  def type_key
    champion_template.type_key
  end
end
