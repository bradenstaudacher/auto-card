# Grants XP to every deployed champion after a battle, based on encounter
# difficulty plus that unit's performance (kills / healing / damage). Tuned so a
# typical fight yields ~50-80 XP -> L2 in ~2 fights, L3 in ~3 more, L4 needs
# card-feeding (see Leveling for thresholds). Persists xp_awards on the round for
# the UI to surface level-ups.
class ExperienceAward
  PARTICIPATION = 25   # just for fighting this round
  ENEMY_WEIGHT  = 5    # * enemy count * round stat scale
  KILL          = 12
  HEAL_PER      = 10   # 1 XP per 10 healing done to allies
  DMG_PER       = 25   # 1 XP per 25 damage dealt
  WIN_BONUS     = 15

  def self.grant!(round)
    new(round).grant!
  end

  def initialize(round)
    @round = round
  end

  def grant!
    deployed = deployed_characters
    return [] if deployed.empty?

    metrics = BattleMetrics.compute(@round.timeline || [], team_lookup)
    won = @round.result_data&.dig("winner") == "allies"
    enemy_bonus = (ENEMY_WEIGHT * enemy_count * stat_scale).round

    awards = deployed.map do |pc|
      m = metrics["pc_#{pc.id}"] || { "damage_dealt" => 0, "healing_done" => 0, "kills" => 0 }
      xp = PARTICIPATION + enemy_bonus +
           (m["kills"] * KILL) +
           (m["healing_done"] / HEAL_PER) +
           (m["damage_dealt"] / DMG_PER) +
           (won ? WIN_BONUS : 0)
      from = pc.level
      pc.add_xp!(xp)
      { "player_character_id" => pc.id, "name" => pc.champion_template.name,
        "xp" => xp, "from_level" => from, "to_level" => pc.level, "metrics" => m }
    end

    @round.update!(result_data: (@round.result_data || {}).merge("xp_awards" => awards))
    awards
  end

  private

  def deployed_characters
    ids = @round.placement_data.values.flatten.map { |p| p["player_character_id"] }
    PlayerCharacter.where(id: ids).includes(:champion_template).to_a
  end

  def enemy_count
    (@round.encounter_data["units"] || []).size
  end

  def stat_scale
    GameContent.single_player_round(@round.round_number)["stat_scale"] || 1.0
  rescue KeyError
    1.0
  end

  # Ally ids are "pc_<id>" (from ChampionUnitSpec); monsters are encounter unit ids.
  def team_lookup
    ally_ids = @round.placement_data.values.flatten.map { |p| "pc_#{p['player_character_id']}" }.to_set
    monster_ids = (@round.encounter_data["units"] || []).map { |u| u["id"] }.to_set
    ->(id) { ally_ids.include?(id) ? "allies" : (monster_ids.include?(id) ? "monsters" : nil) }
  end
end
