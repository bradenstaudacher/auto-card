require "spec_helper"

RSpec.describe Combat::Damage do
  def unit(type:, armor: 0, resist: 0)
    Combat::Unit.new(
      id: "u", team: "t", name: "n", type: type,
      position: { x: 0, y: 0 },
      stats: { health: 100, attack_damage: 10, magic_power: 10,
               armor: armor, resist: resist, mana_cap: 5, mana_regen: 1,
               movement_speed: 1, attack_range: 1, attack_speed: 1.0 }
    )
  end

  it "applies flat armor mitigation, floored at 1" do
    atk = unit(type: "Fury")
    dfn = unit(type: "Fury", armor: 4)
    expect(described_class.physical(raw: 10, attacker: atk, defender: dfn)).to eq(6)
    expect(described_class.physical(raw: 3, attacker: atk, defender: dfn)).to eq(1)
  end

  it "applies flat resist mitigation to magic" do
    atk = unit(type: "Occult")
    dfn = unit(type: "Occult", resist: 6)
    expect(described_class.magic(raw: 20, attacker: atk, defender: dfn)).to eq(14)
  end

  it "amplifies by type advantage BEFORE mitigation" do
    # Fury > Law. raw 20 * 1.25 = 25, minus 5 armor = 20.
    atk = unit(type: "Fury")
    dfn = unit(type: "Law", armor: 5)
    expect(described_class.physical(raw: 20, attacker: atk, defender: dfn)).to eq(20)
  end
end
