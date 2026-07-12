require "spec_helper"

RSpec.describe "status effects" do
  def spec(id:, team:, x:, y:, on_hit: [], **over)
    { id: id, team: team, name: id, type: "Law", position: { x: x, y: y },
      on_hit: on_hit,
      stats: { health: 100, attack_damage: 10, magic_power: 10, armor: 0, shield: 0,
               mana_cap: 5, mana_regen: 1, movement_speed: 0, attack_range: 1,
               attack_speed: 1.0 }.merge(over) }
  end

  it "applies an on-hit status that deals damage over time" do
    # chance 1.0 = deterministic. Attacker adjacent to a passive dummy.
    atk = spec(id: "atk", team: "allies", x: 0, y: 0,
               on_hit: [{ "type" => "bleed", "chance" => 1.0, "damage" => 5, "duration" => 3 }])
    dummy = spec(id: "dummy", team: "monsters", x: 1, y: 0, health: 500,
                 attack_damage: 0, attack_speed: 5.0)
    out = Combat::Simulator.new({ seed: "s", grid: { rows: 3, columns: 3 }, units: [atk, dummy] },
                                max_seconds: 3).run
    expect(out[:events]).to include(a_hash_including(type: "status_applied", effect: "bleed"))
    expect(out[:events]).to include(a_hash_including(type: "status", effect: "bleed", damage: 5))
  end

  it "cleanses all statuses via StatusEffects.cleanse" do
    u = Combat::Unit.new(spec(id: "u", team: "allies", x: 0, y: 0))
    Combat::StatusEffects.apply(u, kind: "poison", damage: 3, duration: 4, source_id: "x")
    Combat::StatusEffects.apply(u, kind: "burn", damage: 2, duration: 2, source_id: "x")
    expect(Combat::StatusEffects.active?(u)).to be(true)
    cleared = Combat::StatusEffects.cleanse(u)
    expect(cleared).to contain_exactly("poison", "burn")
    expect(u.statuses).to be_empty
  end

  it "refreshes rather than stacks a repeated status, keeping the stronger values" do
    u = Combat::Unit.new(spec(id: "u", team: "allies", x: 0, y: 0))
    Combat::StatusEffects.apply(u, kind: "bleed", damage: 4, duration: 2, source_id: "x")
    Combat::StatusEffects.apply(u, kind: "bleed", damage: 6, duration: 1, source_id: "x")
    expect(u.statuses.size).to eq(1)
    expect(u.statuses.first["damage"]).to eq(6)
    expect(u.statuses.first["remaining"]).to eq(2)
  end
end
