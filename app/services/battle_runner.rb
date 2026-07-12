# Assembles a battle from a BattleRound's stored placement + encounter data,
# runs the deterministic engine server-side, and persists the result/timeline.
# The client only ever replays what this produces.
class BattleRunner
  def self.run!(battle_round)
    new(battle_round).run!
  end

  def initialize(battle_round)
    @round = battle_round
  end

  def run!
    input = {
      seed: @round.battle_seed,
      grid: BattleLayout.grid,
      units: ally_units + monster_units
    }
    output = Combat::Simulator.new(input).run
    persist!(output)
    output
  end

  private

  def ally_units
    placements = @round.placement_data.values.flatten
    pc_ids = placements.map { |p| p["player_character_id"] }
    by_id = PlayerCharacter.where(id: pc_ids)
                           .includes(:champion_template, player_cards: :card_template)
                           .index_by(&:id)
    placements.map do |p|
      pc = by_id.fetch(p["player_character_id"])
      ChampionUnitSpec.build(pc, position: { x: p["x"], y: p["y"] })
    end
  end

  def monster_units
    @round.encounter_data.fetch("units").map { |u| symbolize(u) }
  end

  def persist!(output)
    @round.update!(
      status: "resolved",
      result_data: output.except(:events).deep_stringify_keys,
      timeline: output[:events].map { |e| e.deep_stringify_keys }
    )
    @round.game_session.update!(status: "reward")
  end

  # Engine expects symbol keys for grid/stats/position; JSONB round-trips as strings.
  def symbolize(obj)
    case obj
    when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_sym] = symbolize(v) }
    when Array then obj.map { |v| symbolize(v) }
    else obj
    end
  end
end
