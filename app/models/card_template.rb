class CardTemplate < ApplicationRecord
  CATEGORIES = %w[ability weapon equipment passive modifier xp].freeze
  RARITIES = %w[common uncommon rare].freeze

  has_many :player_cards, dependent: :restrict_with_exception

  validates :key, :name, :category, :slot_type, presence: true
  validates :key, uniqueness: true
  validates :category, inclusion: { in: CATEGORIES }
  validates :rarity, inclusion: { in: RARITIES }

  scope :by_rarity, ->(r) { where(rarity: r) }
  scope :base_tier, -> { where(tier: 1) } # only base cards appear in reward offers

  # The template three of these combine into, if any.
  def upgrade_template
    return nil if upgrades_to_key.blank?
    CardTemplate.find_by(key: upgrades_to_key)
  end

  # For ability cards, the combat engine ability name lives in rules.
  def ability_name
    rules["ability_name"] || name
  end
end
