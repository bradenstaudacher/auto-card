require "rails_helper"

RSpec.describe Leveling do
  it "maps xp to level at the doubling thresholds" do
    expect(Leveling.level_for(0)).to eq(1)
    expect(Leveling.level_for(99)).to eq(1)
    expect(Leveling.level_for(100)).to eq(2)
    expect(Leveling.level_for(299)).to eq(2)
    expect(Leveling.level_for(300)).to eq(3)
    expect(Leveling.level_for(700)).to eq(4)
    expect(Leveling.level_for(99999)).to eq(4) # capped at MAX_LEVEL
  end

  it "accumulates slot unlocks across levels" do
    expect(Leveling.bonus_slots(2)).to eq({})
    expect(Leveling.bonus_slots(3)).to eq("equipment_slots" => 1)
    expect(Leveling.bonus_slots(4)).to eq("equipment_slots" => 1, "ability_slots" => 1)
  end

  it "reports progress within the current level" do
    p = Leveling.progress(150) # level 2 (floor 100, ceil 300)
    expect(p[:level]).to eq(2)
    expect(p[:into_level]).to eq(50)
    expect(p[:needed]).to eq(200)
    expect(p[:to_next]).to eq(150)
    expect(p[:max]).to be(false)

    top = Leveling.progress(700)
    expect(top[:max]).to be(true)
    expect(top[:needed]).to be_nil
  end
end

RSpec.describe PlayerCharacter do
  let(:template) do
    ChampionTemplate.create!(key: "t_test", name: "Tester", type_key: "Fury", subclass: "Warrior",
      base_stats: { "health" => 100, "attack_damage" => 10, "magic_power" => 8, "armor" => 5 },
      slot_config: { "weapon_slots" => 1, "equipment_slots" => 0, "passive_slots" => 1, "ability_slots" => 1 },
      default_abilities: [])
  end
  let(:user) { User.create!(handle: "u") }
  let(:session) { GameSession.create!(mode: "single_player", status: "preparation", current_round: 1, max_rounds: 10, seed: "s") }
  let(:player) { session.players.create!(user: user, seat: 1) }
  let(:pc) { player.player_characters.create!(champion_template: template, current_stats: template.base_stats, ability_priority: []) }

  it "scales grown stats by level but leaves others untouched" do
    pc.update!(level: 3) # x1.32
    stats = pc.leveled_base_stats
    expect(stats["health"]).to eq(132)        # 100 * 1.32
    expect(stats["attack_damage"]).to eq(13)  # 10 * 1.32 -> 13.2 -> 13
    expect(stats["magic_power"]).to eq(11)     # 8 * 1.32 -> 10.56 -> 11
    expect(stats["armor"]).to eq(5)           # unchanged
  end

  it "adds level-unlocked slots on top of the template" do
    pc.update!(level: 4)
    expect(pc.slot_count("equipment_slots")).to eq(1) # 0 + 1 (L3)
    expect(pc.slot_count("ability_slots")).to eq(2)   # 1 + 1 (L4)
    expect(pc.slot_count("weapon_slots")).to eq(1)    # unchanged
  end

  it "grants xp, levels up, and reports levels gained" do
    expect(pc.add_xp!(100)).to eq(1) # 0 -> 100 crosses into L2
    expect(pc.level).to eq(2)
    expect(pc.add_xp!(600)).to eq(2) # 100 -> 700 crosses L3 and L4
    expect(pc.level).to eq(4)
    expect(pc.add_xp!(0)).to eq(0)
  end
end
