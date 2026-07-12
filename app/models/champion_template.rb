class ChampionTemplate < ApplicationRecord
  has_many :player_characters, dependent: :restrict_with_exception

  validates :key, :name, :type_key, presence: true
  validates :key, uniqueness: true

  def slot_count(slot)
    slot_config[slot.to_s].to_i
  end
end
