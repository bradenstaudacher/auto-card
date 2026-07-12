require "spec_helper"

RSpec.describe "roster modifier: on-kill mana" do
  def ally(on_kill:)
    { id: "hero", team: "allies", type: "Fury", name: "Hero", position: { x: 0, y: 0 },
      modifiers: { "on_kill_mana" => on_kill },
      stats: { health: 500, attack_damage: 50, magic_power: 0, armor: 0, shield: 0,
               mana_cap: 100, mana_regen: 1, movement_speed: 0, attack_range: 1,
               attack_speed: 1.0 }, abilities: [] }
  end

  def foe
    { id: "foe", team: "monsters", type: "Law", name: "Foe", position: { x: 1, y: 0 },
      stats: { health: 10, attack_damage: 0, magic_power: 0, armor: 0, shield: 0,
               mana_cap: 5, mana_regen: 1, movement_speed: 0, attack_range: 1,
               attack_speed: 1.0 }, abilities: [] }
  end

  def final_mana(on_kill)
    out = Combat::Simulator.new(
      { seed: "k", grid: { rows: 3, columns: 3 }, units: [ally(on_kill: on_kill), foe] }
    ).run
    out[:final_units].find { |u| u[:id] == "hero" }[:mana]
  end

  it "grants bonus mana on a kill (vs no modifier), same battle timing" do
    expect(final_mana(3)).to eq(final_mana(0) + 3)
  end
end
