# Builds the monster side of a battle from a round's config. Monsters are
# auto-placed deterministically in the right-side zone and scaled by the
# round's stat_scale. Output is engine-ready unit specs + placement metadata
# stored on the BattleRound as encounter_data.
class EncounterBuilder
  SCALED_STATS = %w[health attack_damage magic_power].freeze

  def self.build(round_config)
    new(round_config).build
  end

  def initialize(round_config)
    @config = round_config
    @scale = (round_config["stat_scale"] || 1.0).to_f
  end

  def build
    keys = @config.fetch("monsters")
    units = keys.each_with_index.map do |key, i|
      template = GameContent.monster(key)
      pos = placement(i, keys.size)
      {
        id: "monster_#{i + 1}",
        team: "monsters",
        name: template["name"],
        type: template["type"],
        subclass: nil,
        position: pos,
        stats: scaled_stats(template["base_stats"]),
        abilities: monster_abilities(template),
        on_hit: monster_on_hit(template)
      }
    end
    { "monsters" => keys, "scale" => @scale, "units" => units.map { |u| stringify(u) } }
  end

  private

  # Fill the top enemy rows left-to-right, wrapping to the next row. Columns are
  # centered so small groups sit toward the middle. Deterministic in order.
  def placement(index, count)
    cols = BattleLayout::COLUMNS
    rows = BattleLayout::MONSTER_ROWS.to_a
    per_row = [count, cols].min
    offset = [(cols - per_row) / 2, 0].max
    col = offset + (index % per_row)
    row = rows[(index / per_row).clamp(0, rows.size - 1)]
    { "x" => col, "y" => row }
  end

  # Monster abilities from the template, with optional per-ability params.
  def monster_abilities(template)
    params = template["ability_params"] || {}
    Array(template["default_abilities"]).each_with_index.map do |name, i|
      { name: name, priority: i + 1, params: params[name] || {} }
    end
  end

  # Monster on-hit statuses from combat_effects (e.g. Ash Hound burn).
  def monster_on_hit(template)
    (template["combat_effects"] || {}).filter_map do |kind, cfg|
      next unless cfg.is_a?(Hash) && cfg["chance"]
      { "type" => kind, "chance" => cfg["chance"],
        "damage" => cfg["damage"], "duration" => cfg["duration"] }
    end
  end

  def scaled_stats(stats)
    scaled = stats.dup
    SCALED_STATS.each do |k|
      scaled[k] = (stats[k] * @scale).round if stats[k]
    end
    scaled
  end

  def stringify(hash)
    hash.deep_stringify_keys
  end
end
