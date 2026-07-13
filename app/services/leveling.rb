# Character progression rules — the single source of truth for XP thresholds,
# per-level stat growth, and slot unlocks. Kept as pure data + functions so
# PlayerCharacter, combat, and the serializer all agree.
#
# Progression (per the design): L1->2 in ~2 fights, L2->3 in ~3 more, L4 needs
# card-feeding. XP thresholds double each tier (gaps 100 / 200 / 400).
module Leveling
  MAX_LEVEL = 4

  # Cumulative XP required to BE at a level.
  THRESHOLDS = { 1 => 0, 2 => 100, 3 => 300, 4 => 700 }.freeze

  # Multiplicative stat growth applied to the grown stats at each level.
  STAT_MULT = { 1 => 1.0, 2 => 1.15, 3 => 1.32, 4 => 1.52 }.freeze
  GROWN_STATS = %w[health attack_damage magic_power].freeze

  # Extra slots unlocked AT a level (cumulative across levels reached).
  BONUS_SLOTS = {
    3 => { "equipment_slots" => 1 },
    4 => { "ability_slots" => 1 },
  }.freeze

  module_function

  def level_for(xp)
    THRESHOLDS.select { |_lvl, req| xp >= req }.keys.max || 1
  end

  # Sum of slot bonuses from every level up to and including `level`.
  def bonus_slots(level)
    (1..level).each_with_object(Hash.new(0)) do |lvl, acc|
      (BONUS_SLOTS[lvl] || {}).each { |k, v| acc[k] += v }
    end
  end

  def stat_multiplier(level)
    STAT_MULT[level] || STAT_MULT[MAX_LEVEL]
  end

  # Progress within the current level, for the UI bar. At max level, `needed`
  # is nil (bar shows full).
  def progress(xp)
    level = level_for(xp)
    floor = THRESHOLDS[level]
    ceil = THRESHOLDS[level + 1]
    {
      level: level,
      xp: xp,
      into_level: xp - floor,
      needed: ceil ? ceil - floor : nil,
      to_next: ceil ? ceil - xp : nil,
      max: level >= MAX_LEVEL,
    }
  end
end
