# Converts a persisted PlayerCharacter into a Combat engine unit spec (the
# `allies` side). Applies equipped-card stat modifiers and ability grants so
# the same code serves M2 (no equipment) and M4 (full loadouts) unchanged.
class ChampionUnitSpec
  STAT_KEYS = Combat::Unit::STAT_KEYS.map(&:to_s).freeze

  def self.build(player_character, position:)
    new(player_character, position).build
  end

  def initialize(player_character, position)
    @pc = player_character
    @template = player_character.champion_template
    @position = position
  end

  def build
    {
      id: "pc_#{@pc.id}",
      team: "allies",
      name: @template.name,
      type: @template.type_key,
      subclass: @template.subclass,
      position: { x: @position[:x], y: @position[:y] },
      stats: stats,
      abilities: abilities,
      on_hit: on_hit_effects,
      modifiers: roster_modifiers,
      start_effects: start_effects,
      immunities: immunities,
      silence_aura: silence_aura,
      scales_to_target: scales_to_target,
      lifesteal: combat_effect_max("lifesteal"),
      bonus_vs_higher_max_health: combat_effect_max("bonus_vs_higher_max_health"),
      attack_gain_per_attack: combat_effect_max("attack_gain_per_attack"),
      attack_gain_cap: combat_effect_max("attack_gain_cap"),
      auras: auras,
      dot_bonus_damage: combat_effect_max("dot_bonus_damage"),
      dot_bonus_duration: combat_effect_max("dot_bonus_duration")
    }
  end

  private

  def stats
    base = symbolize(@template.base_stats.dup)
    equipped_cards.each do |card|
      (card.card_template.rules["stat_modifiers"] || {}).each do |stat, delta|
        key = stat.to_sym
        base[key] = (base[key] || 0) + delta
      end
    end
    base
  end

  # Cast priority follows the character's persisted ability_priority order,
  # filtered to abilities it actually has access to (defaults + equipped ability
  # cards). Falls back to defaults if the order is somehow empty.
  def abilities
    available = Array(@template.default_abilities) +
                equipped_cards.select { |c| c.category == "ability" }.map(&:ability_name)
    available = available.uniq

    ordered = Array(@pc.ability_priority).select { |name| available.include?(name) }
    ordered = available if ordered.empty?
    ordered.each_with_index.map do |name, i|
      { name: name, priority: i + 1, params: ability_params[name] || {} }
    end
  end

  # Tunables from equipped ability cards keyed by ability name. When multiple
  # cards grant the same ability, the highest-tier (strongest) card wins.
  def ability_params
    @ability_params ||= equipped_cards
      .select { |c| c.category == "ability" }
      .sort_by { |c| c.card_template.tier }
      .each_with_object({}) do |c, h|
        params = c.card_template.rules["ability_params"]
        h[c.ability_name] = params if params.present?
      end
  end

  # Weapon/equipment combat_effects that read as {chance,damage,duration} become
  # on-hit status appliers (e.g. Serrated Blade's bleed).
  def on_hit_effects
    equipped_cards.flat_map do |card|
      (card.card_template.rules["combat_effects"] || {}).filter_map do |kind, cfg|
        next unless cfg.is_a?(Hash) && cfg["chance"]
        { "type" => kind, "chance" => cfg["chance"],
          "damage" => cfg["damage"], "duration" => cfg["duration"] }
      end
    end
  end

  # Numeric combat effects from the player's roster-modifier cards that apply to
  # this champion (respecting an optional applies_to_type filter). e.g. Crimson
  # Momentum grants Fury champions on_kill_mana.
  NUMERIC_MODIFIERS = %w[on_kill_mana].freeze

  def roster_modifiers
    mods = {}
    roster_modifier_cards.each do |card|
      effects = card.card_template.rules["combat_effects"] || {}
      applies = effects["applies_to_type"]
      next if applies.present? && applies != @template.type_key
      NUMERIC_MODIFIERS.each do |k|
        mods[k] = (mods[k] || 0) + effects[k] if effects[k]
      end
    end
    mods
  end

  # Passive combat_effects that fire once at battle start (self-buffs conditional
  # on adjacency), e.g. Lawful Formation armor, Martyr's Vow shield. Summed by
  # kind; the simulator applies them before the first tick.
  START_EFFECT_KINDS = %w[adjacent_ally_armor adjacent_ally_shield].freeze

  def start_effects
    effects = Hash.new(0)
    equipped_cards.each do |card|
      (card.card_template.rules["combat_effects"] || {}).each do |kind, amount|
        effects[kind] += amount if START_EFFECT_KINDS.include?(kind)
      end
    end
    effects
  end

  # Status kinds the champion is immune to, from any equipped card's
  # combat_effects.status_immunity (e.g. Absolute Resolve). Deduplicated.
  def immunities
    equipped_cards.flat_map do |card|
      Array((card.card_template.rules["combat_effects"] || {})["status_immunity"])
    end.uniq
  end

  # Largest silence-aura radius among equipped cards (Nullification Orb). Enemies
  # within this range of the champion cannot cast.
  def silence_aura
    equipped_cards.map do |card|
      (card.card_template.rules["combat_effects"] || {})["silence_aura"].to_i
    end.max || 0
  end

  # Scales of Power: true if any equipped card grants the target-scaling basic
  # attack.
  def scales_to_target
    equipped_cards.any? do |card|
      (card.card_template.rules["combat_effects"] || {})["scales_to_target"]
    end
  end

  # Battle-start auras from equipped cards. Each aura combat_effect maps to a
  # target stat + who it affects; radius comes from the card's aura_range (2).
  AURA_EFFECTS = {
    "ally_aura_health_regen" => { stat: "health_regen", target: "ally" },
    "ally_aura_armor"        => { stat: "armor",        target: "ally" },
    "enemy_aura_attack"      => { stat: "attack_damage", target: "enemy" },
  }.freeze

  def auras
    equipped_cards.flat_map do |card|
      effects = card.card_template.rules["combat_effects"] || {}
      range = (effects["aura_range"] || 2).to_i
      AURA_EFFECTS.filter_map do |key, spec|
        next unless effects[key]
        { "stat" => spec[:stat], "amount" => effects[key], "range" => range, "target" => spec[:target] }
      end
    end
  end

  # Largest value of a numeric combat_effect across equipped cards (0 if none).
  def combat_effect_max(key)
    equipped_cards.map do |card|
      (card.card_template.rules["combat_effects"] || {})[key]
    end.compact.max || 0
  end

  def roster_modifier_cards
    @roster_modifier_cards ||=
      @pc.player.player_cards.includes(:card_template)
         .select { |c| c.card_template.slot_type == "roster_modifier" }
  end

  def equipped_cards
    @equipped_cards ||= @pc.player_cards.includes(:card_template).to_a
  end

  def symbolize(hash)
    hash.transform_keys(&:to_sym)
  end
end
