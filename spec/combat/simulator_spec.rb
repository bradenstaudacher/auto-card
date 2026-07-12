require "spec_helper"

RSpec.describe Combat::Simulator do
  # Minimal stat block helper; override any field.
  def stats(over = {})
    { health: 100, attack_damage: 12, magic_power: 8, armor: 2, shield: 2,
      mana_cap: 6, mana_regen: 1, movement_speed: 3, attack_range: 1,
      attack_speed: 1.0 }.merge(over)
  end

  def unit(id:, team:, type:, x:, y:, abilities: [], **st)
    { id: id, team: team, name: id, type: type, subclass: nil,
      position: { x: x, y: y }, stats: stats(st), abilities: abilities }
  end

  def input(units, seed: "battle-seed")
    { seed: seed, grid: { rows: 6, columns: 8 }, units: units }
  end

  describe "determinism" do
    let(:units) do
      [
        unit(id: "p1", team: "allies", type: "Death", x: 0, y: 1,
             abilities: [{ name: "Vampiric Drain", priority: 1 }], magic_power: 10),
        unit(id: "p2", team: "allies", type: "Fury", x: 0, y: 3,
             abilities: [{ name: "Cleave", priority: 1 }], attack_damage: 14),
        unit(id: "m1", team: "monsters", type: "Law", x: 7, y: 1, health: 80),
        unit(id: "m2", team: "monsters", type: "Occult", x: 7, y: 3, health: 70)
      ]
    end

    it "produces byte-identical timelines across two runs" do
      out_a = described_class.new(input(units)).run
      out_b = described_class.new(input(units)).run
      expect(out_a).to eq(out_b)
    end

    it "changes outcome timeline when the seed changes only if RNG is used" do
      # No RNG-driven abilities here, so seed should not matter — still deterministic.
      out_a = described_class.new(input(units, seed: "aaa")).run
      out_b = described_class.new(input(units, seed: "zzz")).run
      expect(out_a[:events]).to eq(out_b[:events])
    end
  end

  describe "a full battle" do
    it "resolves to a winner with a valid timeline" do
      units = [
        unit(id: "hero", team: "allies", type: "Fury", x: 1, y: 2,
             health: 200, attack_damage: 20),
        unit(id: "goblin", team: "monsters", type: "Law", x: 6, y: 2, health: 40)
      ]
      out = described_class.new(input(units)).run

      expect(out[:winner]).to eq("allies")
      expect(out[:duration_ticks]).to be > 0
      expect(out[:events]).to include(a_hash_including(type: "move"))
      expect(out[:events]).to include(a_hash_including(type: "attack"))
      expect(out[:events]).to include(a_hash_including(type: "death", unit_id: "goblin"))
      # Every event carries a tick within the battle duration.
      expect(out[:events].map { |e| e[:tick] }.max).to be <= out[:duration_ticks]
    end

    it "runs a 2v3 skirmish to completion" do
      units = [
        unit(id: "a1", team: "allies", type: "Death", x: 0, y: 1, health: 120,
             attack_damage: 16, abilities: [{ name: "Vampiric Drain", priority: 1 }], magic_power: 12),
        unit(id: "a2", team: "allies", type: "Fury", x: 0, y: 4, health: 160,
             attack_damage: 18, abilities: [{ name: "Cleave", priority: 1 }]),
        unit(id: "e1", team: "monsters", type: "Law", x: 7, y: 1, health: 45),
        unit(id: "e2", team: "monsters", type: "Law", x: 7, y: 2, health: 45),
        unit(id: "e3", team: "monsters", type: "Law", x: 7, y: 4, health: 45)
      ]
      out = described_class.new(input(units)).run
      expect(%w[allies monsters draw timeout]).to include(out[:winner])
      expect(out[:final_units].size).to eq(5)
    end
  end

  describe "type advantage in practice" do
    it "kills faster with advantage than without" do
      # Fury > Law. Compare identical fight where only defender type differs.
      def one_v_one(def_type)
        units = [
          unit(id: "atk", team: "allies", type: "Fury", x: 3, y: 2,
               attack_damage: 12, health: 500),
          unit(id: "def", team: "monsters", type: def_type, x: 4, y: 2,
               health: 100, armor: 0, attack_damage: 0)
        ]
        described_class.new(input(units)).run[:duration_ticks]
      end

      advantaged = one_v_one("Law")     # takes bonus damage
      neutral    = one_v_one("Death")   # neutral
      expect(advantaged).to be < neutral
    end
  end

  describe "timeout" do
    it "ends in a timeout when neither side can win" do
      # Two ranged units out of range of each other with no movement.
      units = [
        unit(id: "wall1", team: "allies", type: "Law", x: 0, y: 0,
             movement_speed: 0, attack_range: 1, attack_damage: 0, health: 50),
        unit(id: "wall2", team: "monsters", type: "Law", x: 7, y: 5,
             movement_speed: 0, attack_range: 1, attack_damage: 0, health: 50)
      ]
      out = described_class.new(input(units), max_seconds: 3).run
      expect(out[:winner]).to eq("timeout")
    end
  end
end
