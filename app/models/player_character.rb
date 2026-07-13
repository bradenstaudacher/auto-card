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

  # --- Leveling --------------------------------------------------------------
  # Champion base stats scaled by the character's level (health/attack/magic
  # grow; other stats are unchanged). Combat + the serializer both read this so
  # a leveled champion is stronger everywhere.
  def leveled_base_stats
    mult = Leveling.stat_multiplier(level)
    champion_template.base_stats.each_with_object({}) do |(k, v), out|
      out[k] = Leveling::GROWN_STATS.include?(k.to_s) ? (v * mult).round : v
    end
  end

  # Slot capacities including level unlocks (e.g. +1 equipment at L3).
  def slot_config
    cfg = champion_template.slot_config.dup
    Leveling.bonus_slots(level).each { |k, v| cfg[k] = cfg[k].to_i + v }
    cfg
  end

  def slot_count(key)
    slot_config[key.to_s].to_i
  end

  # Grant XP and recompute level. Returns the levels gained (0 if none) so the
  # caller can surface a level-up. Persists.
  def add_xp!(amount)
    return 0 if amount.to_i <= 0

    before = level
    self.xp += amount.to_i
    self.level = Leveling.level_for(xp)
    save!
    level - before
  end

  def xp_progress
    Leveling.progress(xp)
  end
end
