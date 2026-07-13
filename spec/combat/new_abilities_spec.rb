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

  it "Dawnbreak hits the target and adjacent enemies for magic damage" do
    caster = unit(id: "c", team: "allies", type: "Holy", x: 0, y: 0, mp: 10)
    caster.mana = 5
    e1 = unit(id: "e1", team: "monsters", type: "Fury", x: 2, y: 0, hp: 100)
    e2 = unit(id: "e2", team: "monsters", type: "Fury", x: 3, y: 0, hp: 100) # adjacent to e1
    st = state([caster, e1, e2])
    dmg_events = Combat::Abilities::Dawnbreak.new
      .resolve(caster: caster, state: st, tick: 1).map(&:to_h)
      .select { |ev| ev[:damage_type] == "magic" }
    expect(dmg_events.size).to eq(2)          # both enemies caught in the blast
    expect(dmg_events.map { |ev| ev[:damage] }).to all(eq(13)) # 10 * 1.3, no shield
  end

  it "Dawnbreak wards an adjacent ally with shield" do
    caster = unit(id: "c", team: "allies", type: "Holy", x: 0, y: 0, mp: 10)
    caster.mana = 5
    ally = unit(id: "a", team: "allies", type: "Holy", x: 0, y: 1) # adjacent to caster
    enemy = unit(id: "e", team: "monsters", type: "Fury", x: 3, y: 0, hp: 100)
    st = state([caster, ally, enemy])
    ward = Combat::Abilities::Dawnbreak.new
      .resolve(caster: caster, state: st, tick: 1).map(&:to_h)
      .find { |ev| ev[:damage_type] == "shield" }
    expect(ward[:healing]).to eq(5)   # 10 * 0.5
    expect(ally.stats[:shield]).to eq(5)
  end

  it "battle-start ward (Martyr's Vow) buffs a unit adjacent to an ally" do
    warded = Combat::Unit.new(
      id: "w", team: "allies", type: "Holy", name: "w", position: { x: 0, y: 0 },
      stats: { health: 100, attack_damage: 5, magic_power: 5, armor: 0, shield: 0,
               mana_cap: 5, mana_regen: 1, movement_speed: 0, attack_range: 1, attack_speed: 1.0 },
      start_effects: { "adjacent_ally_shield" => 3 }
    )
    ally = unit(id: "a", team: "allies", type: "Holy", x: 0, y: 1) # adjacent
    enemy = unit(id: "e", team: "monsters", type: "Fury", x: 5, y: 0)
    # apply_start_effects only reads the passed state, so a bare simulator is fine.
    sim = Combat::Simulator.new({ seed: "t", grid: { rows: 6, columns: 8 }, units: [] })
    sim.send(:apply_start_effects, state([warded, ally, enemy]))
    expect(warded.stats[:shield]).to eq(3)
  end

  it "health_regen restores HP per second without overhealing" do
    u = unit(id: "u", team: "allies", type: "Law", x: 0, y: 0, hp: 100, health_regen: 4)
    u.current_health = 50
    sim = Combat::Simulator.new({ seed: "t", grid: { rows: 6, columns: 8 }, units: [] })
    # 4 HP/sec at 250ms ticks = 1 HP/tick. Four ticks -> +4 HP.
    4.times { sim.send(:regenerate_health, u) }
    expect(u.current_health).to eq(54)
    # Cannot exceed max health.
    u.current_health = 99
    10.times { sim.send(:regenerate_health, u) }
    expect(u.current_health).to eq(100)
  end

  it "status immunity (Absolute Resolve) blocks listed kinds but not others" do
    resolute = Combat::Unit.new(
      id: "r", team: "allies", type: "Law", name: "r", position: { x: 0, y: 0 },
      stats: { health: 100, attack_damage: 5, magic_power: 5, armor: 0, shield: 0,
               mana_cap: 5, mana_regen: 1, movement_speed: 0, attack_range: 1, attack_speed: 1.0 },
      immunities: %w[burn poison bleed]
    )
    expect(Combat::StatusEffects.apply(resolute, kind: "burn", damage: 4, duration: 2, source_id: "x")).to be_nil
    expect(resolute.statuses).to be_empty
    # A kind not on the immunity list still lands (nothing immune to it here).
    resolute2 = Combat::Unit.new(
      id: "r2", team: "allies", type: "Law", name: "r2", position: { x: 0, y: 0 },
      stats: resolute.stats, immunities: %w[burn]
    )
    Combat::StatusEffects.apply(resolute2, kind: "poison", damage: 3, duration: 2, source_id: "x")
    expect(resolute2.statuses.map { |s| s["type"] }).to eq(%w[poison])
  end

  it "silence aura (Nullification Orb) stops enemy casting within range" do
    orb = Combat::Unit.new(
      id: "orb", team: "allies", type: "Law", name: "orb", position: { x: 3, y: 0 },
      stats: { health: 100, attack_damage: 5, magic_power: 5, armor: 0, shield: 0,
               mana_cap: 5, mana_regen: 1, movement_speed: 0, attack_range: 1, attack_speed: 1.0 },
      silence_aura: 2
    )
    caster = unit(id: "e", team: "monsters", type: "Occult", x: 4, y: 0, mp: 10) # 1 tile away
    caster.mana = 5
    caster.instance_variable_set(:@abilities, ["Hex Bolt"])
    far = unit(id: "e2", team: "monsters", type: "Occult", x: 7, y: 0, mp: 10) # 4 tiles away
    sim = Combat::Simulator.new({ seed: "t", grid: { rows: 6, columns: 8 }, units: [] })
    expect(sim.send(:silenced?, caster, state([orb, caster, far]))).to be(true)
    expect(sim.send(:silenced?, far, state([orb, caster, far]))).to be(false)
  end

  it "Soul Crush deals true damage ignoring armor and shield" do
    caster = unit(id: "c", team: "allies", type: "Death", x: 0, y: 0, mp: 10)
    caster.mana = 5
    tank = unit(id: "t", team: "monsters", type: "Death", x: 2, y: 0, hp: 100, armor: 50, shield: 50)
    ev = Combat::Abilities::SoulCrush.new
      .resolve(caster: caster, state: state([caster, tank]), tick: 1).first.to_h
    expect(ev[:damage]).to eq(4)          # 10 * 0.4, mitigation ignored
    expect(ev[:damage_type]).to eq("true")
    expect(tank.current_health).to eq(96) # 100 - 4, armor/shield did nothing
  end

  it "Scales of Power makes a weak attacker hit with a stronger target's power" do
    weak = Combat::Unit.new(
      id: "w", team: "allies", type: "Fury", name: "w", position: { x: 0, y: 0 },
      stats: { health: 100, attack_damage: 5, magic_power: 0, armor: 0, shield: 0,
               mana_cap: 5, mana_regen: 0, movement_speed: 0, attack_range: 1, attack_speed: 1.0 },
      scales_to_target: true
    )
    boss = unit(id: "b", team: "monsters", type: "Fury", x: 1, y: 0, hp: 100)
    boss.stats[:attack_damage] = 30
    sim = Combat::Simulator.new({ seed: "t", grid: { rows: 6, columns: 8 }, units: [] })
    st = state([weak, boss])
    expect(sim.send(:try_attack, weak, boss, st)).to be(true)
    # Borrows the boss's 30 AD (neutral matchup, no armor) instead of its own 5.
    expect(boss.current_health).to eq(70)
  end

  it "Blade of Dromoz heals the attacker for a fraction of damage dealt" do
    u = unit(id: "u", team: "allies", type: "Fury", x: 0, y: 0, attack_damage: 20)
    u.instance_variable_set(:@lifesteal, 0.3)
    u.current_health = 50
    target = unit(id: "t", team: "monsters", type: "Fury", x: 1, y: 0, hp: 100)
    sim = Combat::Simulator.new({ seed: "t", grid: { rows: 6, columns: 8 }, units: [] })
    sim.send(:try_attack, u, target, state([u, target]))
    expect(u.current_health).to eq(56) # 20 dmg * 0.3 = 6 healed
  end

  it "Fellborn Blade adds bonus damage only against higher-max-health targets" do
    u = unit(id: "u", team: "allies", type: "Fury", x: 0, y: 0, hp: 100, attack_damage: 10)
    u.instance_variable_set(:@bonus_vs_higher_max_health, 6)
    big = unit(id: "big", team: "monsters", type: "Fury", x: 1, y: 0, hp: 200)
    small = unit(id: "small", team: "monsters", type: "Fury", x: 0, y: 1, hp: 50)
    sim = Combat::Simulator.new({ seed: "t", grid: { rows: 6, columns: 8 }, units: [] })
    sim.send(:try_attack, u, big, state([u, big, small]))
    expect(big.current_health).to eq(184) # 200 - (10+6)
    u.attack_cooldown = 0
    sim.send(:try_attack, u, small, state([u, big, small]))
    expect(small.current_health).to eq(40) # 50 - 10, no bonus
  end

  it "Frenzy ramps attack damage each hit up to the cap" do
    u = unit(id: "u", team: "allies", type: "Fury", x: 0, y: 0, attack_damage: 10)
    u.instance_variable_set(:@attack_gain_per_attack, 2)
    u.instance_variable_set(:@attack_gain_cap, 5)
    sim = Combat::Simulator.new({ seed: "t", grid: { rows: 6, columns: 8 }, units: [] })
    3.times { sim.send(:ramp_attack, u) }
    expect(u.stats[:attack_damage]).to eq(15) # +2, +2, +1 (capped at +5)
    expect(u.attack_gained).to eq(5)
  end

  it "auras buff allies / debuff enemies within range at battle start" do
    src = Combat::Unit.new(
      id: "src", team: "allies", type: "Holy", name: "src", position: { x: 0, y: 0 },
      stats: { health: 100, attack_damage: 5, magic_power: 5, armor: 0, shield: 0,
               mana_cap: 5, mana_regen: 1, movement_speed: 0, attack_range: 1, attack_speed: 1.0 },
      auras: [
        { "stat" => "armor", "amount" => 3, "range" => 2, "target" => "ally" },
        { "stat" => "attack_damage", "amount" => -3, "range" => 2, "target" => "enemy" },
      ]
    )
    ally = unit(id: "a", team: "allies", type: "Law", x: 1, y: 0)      # in range
    enemy_near = unit(id: "e", team: "monsters", type: "Fury", x: 2, y: 0, attack_damage: 10) # dist 2
    enemy_far = unit(id: "f", team: "monsters", type: "Fury", x: 5, y: 0, attack_damage: 10)  # dist 5
    sim = Combat::Simulator.new({ seed: "t", grid: { rows: 6, columns: 8 }, units: [] })
    sim.send(:apply_auras, state([src, ally, enemy_near, enemy_far]))
    expect(ally.stats[:armor]).to eq(3)          # +3 armor from ally aura
    expect(enemy_near.stats[:attack_damage]).to eq(7)  # -3 within range
    expect(enemy_far.stats[:attack_damage]).to eq(10)  # untouched, out of range
    expect(src.stats[:armor]).to eq(0)           # aura targets others, not self
  end

  it "Plaguebearer amplifies DoTs the unit applies (damage + duration)" do
    attacker = Combat::Unit.new(
      id: "p", team: "allies", type: "Occult", name: "p", position: { x: 0, y: 0 },
      stats: { health: 100, attack_damage: 5, magic_power: 5, armor: 0, shield: 0,
               mana_cap: 5, mana_regen: 1, movement_speed: 0, attack_range: 1, attack_speed: 1.0 },
      on_hit: [{ "type" => "poison", "chance" => 1.0, "damage" => 4, "duration" => 2 }],
      dot_bonus_damage: 1, dot_bonus_duration: 1
    )
    target = unit(id: "t", team: "monsters", type: "Fury", x: 1, y: 0, hp: 100)
    sim = Combat::Simulator.new({ seed: "always", grid: { rows: 6, columns: 8 }, units: [] })
    sim.send(:apply_on_hit, attacker, target, state([attacker, target]))
    s = target.statuses.find { |x| x["type"] == "poison" }
    expect(s["damage"]).to eq(5)     # 4 + 1
    expect(s["remaining"]).to eq(3)  # 2 + 1
  end
end
