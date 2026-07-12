class PlayerCard < ApplicationRecord
  belongs_to :player
  belongs_to :card_template
  belongs_to :assigned_character, class_name: "PlayerCharacter",
             foreign_key: :assigned_to_player_character_id, optional: true

  delegate :category, :slot_type, :name, :ability_name, to: :card_template

  def assigned?
    assigned_to_player_character_id.present?
  end
end
