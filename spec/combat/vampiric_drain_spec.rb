require "spec_helper"

RSpec.describe Combat::Abilities::VampiricDrain do
  # Target type defaults to Law (neutral vs the Death caster) so tests isolate
  # the ability math from the type-advantage multiplier.
  def build_state(caster_hp:, target_hp:, target_shield: 0, distance: 2, target_type: "Law")
    caster = Combat::Unit.new(
      id: "caster", team: "allies", name: "Reaper", type: "Death",
      position: { x: 0, y: 0 },
      stats: { health: 100, attack_damage: 5, magic_power: 8, armor: 0,
               shield: 0, mana_cap: 5, mana_regen: 1, movement_speed: 1,
               attack_range: 1, attack_speed: 1.0 }
    )
    caster.current_health = caster_hp
    caster.mana = 5

    target = Combat::Unit.new(
      id: "target", team: "monsters", name: "Brute", type: target_type,
      position: { x: distance, y: 0 },
      stats: { health: 400, attack_damage: 5, magic_power: 0, armor: 0,
               shield: target_shield, mana_cap: 5, mana_regen: 1,
               movement_speed: 1, attack_range: 1, attack_speed: 1.0 }
    )
    target.current_health = target_hp

    grid = Combat::Grid.new(rows: 6, columns: 8)
    Combat::BattleState.new(grid: grid, units: [caster, target], prng: Combat::Prng.new("t"))
  end

  it "deals 25% current health as damage and heals the caster for it" do
    state = build_state(caster_hp: 50, target_hp: 100)
    caster = state.find("caster")
    events = described_class.new.resolve(caster: caster, state: state, tick: 1)

    ev = events.first.to_h
    expect(ev[:damage]).to eq(25)          # 25% of 100
    expect(ev[:healing]).to eq(25)
    expect(caster.current_health).to eq(75)
    expect(state.find("target").current_health).to eq(75)
    expect(caster.mana).to eq(2)           # spent 3
  end

  it "clamps damage to the maximum of 40" do
    state = build_state(caster_hp: 10, target_hp: 400) # 25% = 100 -> capped 40
    caster = state.find("caster")
    ev = described_class.new.resolve(caster: caster, state: state, tick: 1).first.to_h
    expect(ev[:damage]).to eq(40)
  end

  it "clamps damage to the minimum of 5" do
    state = build_state(caster_hp: 100, target_hp: 8) # 25% = 2 -> floored 5
    caster = state.find("caster")
    ev = described_class.new.resolve(caster: caster, state: state, tick: 1).first.to_h
    expect(ev[:damage]).to eq(5)
  end

  it "does not overheal past max health" do
    state = build_state(caster_hp: 95, target_hp: 100) # heal 25 but only 5 missing
    caster = state.find("caster")
    ev = described_class.new.resolve(caster: caster, state: state, tick: 1).first.to_h
    expect(ev[:healing]).to eq(5)
    expect(caster.current_health).to eq(100)
  end

  it "is not castable out of range" do
    state = build_state(caster_hp: 50, target_hp: 100, distance: 5)
    caster = state.find("caster")
    expect(described_class.new.castable?(caster, state)).to be(false)
  end
end
