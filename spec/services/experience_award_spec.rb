require "rails_helper"

RSpec.describe BattleMetrics do
  let(:team) { ->(id) { id.start_with?("pc_") ? "allies" : "monsters" } }

  it "tallies damage, ally healing, and kills; ignores self-heal" do
    events = [
      { "type" => "attack", "source_id" => "pc_1", "target_id" => "m1", "damage" => 10 },
      { "type" => "cast", "source_id" => "pc_1", "target_id" => "m1", "damage" => 20 },
      { "type" => "death", "unit_id" => "m1" },
      { "type" => "cast", "source_id" => "pc_2", "target_id" => "pc_1", "damage" => 0, "healing" => 15 },
      # Vampiric-style self-heal: heals self, targets an enemy, sets source_health_after.
      { "type" => "cast", "source_id" => "pc_3", "target_id" => "m2", "damage" => 5, "healing" => 5, "source_health_after" => 40 },
    ]
    m = BattleMetrics.compute(events, team)
    expect(m["pc_1"]).to eq("damage_dealt" => 30, "healing_done" => 0, "kills" => 1)
    expect(m["pc_2"]["healing_done"]).to eq(15)
    expect(m["pc_3"]).to eq("damage_dealt" => 5, "healing_done" => 0, "kills" => 0) # self-heal not counted
  end

  it "credits a DoT kill to the effect's applier" do
    events = [
      { "type" => "status", "unit_id" => "m1", "source_id" => "pc_9", "damage" => 4 },
      { "type" => "death", "unit_id" => "m1" },
    ]
    expect(BattleMetrics.compute(events, team)["pc_9"]["kills"]).to eq(1)
  end
end

RSpec.describe ExperienceAward do
  let(:template) do
    ChampionTemplate.create!(key: "t_xp", name: "XPer", type_key: "Fury", subclass: "Warrior",
      base_stats: { "health" => 100 }, slot_config: {}, default_abilities: [])
  end
  let(:user) { User.create!(handle: "u") }
  let(:session) { GameSession.create!(mode: "single_player", status: "battle", current_round: 1, max_rounds: 10, seed: "s") }
  let(:player) { session.players.create!(user: user, seat: 1) }
  let(:pc) { player.player_characters.create!(champion_template: template, current_stats: {}, ability_priority: []) }

  it "grants encounter + performance XP and records the award" do
    round = session.battle_rounds.create!(
      round_number: 1, status: "resolved", battle_seed: "s-r1",
      encounter_data: { "units" => [{ "id" => "m1" }, { "id" => "m2" }] },
      placement_data: { "1" => [{ "player_character_id" => pc.id, "x" => 0, "y" => 5 }] },
      result_data: { "winner" => "allies" },
      timeline: [
        { "type" => "attack", "source_id" => "pc_#{pc.id}", "target_id" => "m1", "damage" => 50 },
        { "type" => "death", "unit_id" => "m1" },
      ]
    )
    awards = ExperienceAward.grant!(round)
    # 25 participation + (5*2 enemies*1.0)=10 + 1 kill*12 + 50/25=2 dmg + 15 win = 64
    expect(awards.first["xp"]).to eq(64)
    expect(pc.reload.xp).to eq(64)
    expect(round.reload.result_data["xp_awards"].first["metrics"]["kills"]).to eq(1)
  end
end
