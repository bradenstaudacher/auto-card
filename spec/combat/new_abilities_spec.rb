require "spec_helper"

RSpec.describe "new abilities" do
  def unit(id:, team:, type:, x:, y:, hp: 100, mp: 10, **over)
    Combat::Unit.new(
      id: id, team: team, name: id, type: type, position: { x: x, y: y },
      stats: { health: hp, attack_damage: 5, magic_power: mp, armor: 0, shield: 0,
               mana_cap: 5, mana_regen: 1, movement_speed: 0, attack_range: 1,
               attack_speed: 1.0 }.merge(over)
    )
  end

  def state(units)
    Combat::BattleState.new(grid: Combat::Grid.new(rows: 6, columns: 8),
                            units: units, prng: Combat::Prng.new("t"))
  end

  it "Hex Bolt deals 160% magic power as magic damage" do
    caster = unit(id: "c", team: "allies", type: "Occult", x: 0, y: 0, mp: 10)
    caster.mana = 5
    target = unit(id: "t", team: "monsters", type: "Occult", x: 2, y: 0, hp: 100)
    st = state([caster, target])
    ev = Combat::Abilities::HexBolt.new.resolve(caster: caster, state: st, tick: 1).first.to_h
    expect(ev[:damage]).to eq(16) # 10 * 1.6, neutral matchup, no shield
  end

  it "Shield Pulse only fires for an injured ally and heals them" do
    healer = unit(id: "h", team: "allies", type: "Law", x: 0, y: 0, mp: 10)
    healer.mana = 5
    hurt = unit(id: "a", team: "allies", type: "Law", x: 1, y: 0, hp: 100)
    hurt.current_health = 40
    st = state([healer, hurt])
    pulse = Combat::Abilities::ShieldPulse.new
    expect(pulse.castable?(healer, st)).to be(true)
    ev = pulse.resolve(caster: healer, state: st, tick: 1).first.to_h
    expect(ev[:healing]).to eq(15) # 10 * 1.5
    expect(hurt.current_health).to eq(55)
  end

  it "Shield Pulse is not castable when all allies are healthy" do
    healer = unit(id: "h", team: "allies", type: "Law", x: 0, y: 0)
    healer.mana = 5
    ally = unit(id: "a", team: "allies", type: "Law", x: 1, y: 0)
    expect(Combat::Abilities::ShieldPulse.new.castable?(healer, state([healer, ally]))).to be(false)
  end
end
