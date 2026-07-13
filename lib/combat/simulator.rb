module Combat
  # Deterministic, server-authoritative battle simulator. Given the input
  # contract (seed, grid, units) it produces a winner + ordered timeline that
  # the client replays. Same input => byte-identical output.
  #
  # Per-tick order (all units resolved in ascending id order):
  #   1. check battle end
  #   2. regen mana, decrement cooldowns
  #   3. select target
  #   4. cast highest-priority castable ability, else
  #   5. basic-attack if in range and off cooldown, else
  #   6. move toward target
  class Simulator
    DEFAULT_TICK_MS = 250
    DEFAULT_MAX_SECONDS = 60

    def initialize(input, tick_ms: DEFAULT_TICK_MS, max_seconds: DEFAULT_MAX_SECONDS)
      @input = symbolize(input)
      @tick_ms = tick_ms
      @tick_seconds = tick_ms / 1000.0
      @max_ticks = (max_seconds * 1000 / tick_ms).to_i
      @events = []
    end

    def run
      grid = Grid.new(**@input[:grid])
      units = @input[:units].map { |u| Unit.new(u) }
      state = BattleState.new(grid: grid, units: units, prng: Prng.new(@input[:seed]))
      apply_start_effects(state)
      apply_auras(state)

      until state.over? || state.tick >= @max_ticks
        state.tick += 1
        step(state)
      end

      build_output(state)
    end

    private

    # One-time battle-start passives for a unit adjacent to any living ally.
    # Lawful Formation adds a static armor stat (no event — shows up in later
    # mitigation). Martyr's Vow grants a grey absorb barrier, which DOES emit a
    # tick-0 event so the client can render the grey bar from the opening frame.
    START_EFFECT_STATS = { "adjacent_ally_armor" => :armor }.freeze

    def apply_start_effects(state)
      state.units.each do |unit|
        next if unit.start_effects.empty?
        next unless state.allies_of(unit).any? { |a| a.alive? && Grid.manhattan(unit.position, a.position) == 1 }

        unit.start_effects.each do |kind, amount|
          if kind == "adjacent_ally_shield"
            unit.add_barrier("Martyr's Vow", amount)
            @events << { tick: state.tick, type: "cast", ability_name: "Martyr's Vow",
                         source_id: unit.id, target_id: unit.id, damage: 0, healing: amount,
                         target_health_after: unit.current_health,
                         target_shield_after: unit.barrier, damage_type: "shield" }
          elsif (stat = START_EFFECT_STATS[kind])
            unit.stats[stat] += amount
          end
        end
      end
    end

    # Passive health regen (health_regen is HP/second). Accumulate the per-tick
    # fraction and apply whole HP so rates like +2/sec stay exact and current
    # health remains an integer. Never overheals or revives the dead.
    def regenerate_health(unit)
      regen = unit.stats[:health_regen].to_f
      return unless regen.positive? && unit.alive? && unit.current_health < unit.stats[:health]

      unit.heal_progress += regen * @tick_seconds
      whole = unit.heal_progress.floor
      return unless whole.positive?

      unit.heal_progress -= whole
      unit.current_health = [unit.current_health + whole, unit.stats[:health]].min
    end

    # Battle-start auras: each aura-carrying unit buffs (or debuffs) the stat of
    # every ally/enemy within its range, snapshotted on the opening formation
    # (Beacon of Vigor, Aegis Standard, Withering Aura). A static stat delta —
    # consistent with the other battle-start passives; positions at t=0.
    def apply_auras(state)
      state.units.each do |source|
        next if source.auras.empty?

        source.auras.each do |aura|
          pool = aura["target"] == "enemy" ? state.enemies_of(source) : state.allies_of(source)
          stat = aura["stat"].to_sym
          amount = aura["amount"].to_i
          range = aura["range"].to_i
          pool.each do |u|
            next unless u.alive? && Grid.manhattan(source.position, u.position) <= range
            u.stats[stat] = (u.stats[stat] || 0) + amount
          end
        end
      end
    end

    def step(state)
      tick_statuses(state)
      state.living_in_order.each do |unit|
        next unless unit.alive? # may have died earlier this tick

        regen_and_cooldowns(unit)

        target = Targeting.select(unit, state.enemies_of(unit))
        next unless target # no enemies left

        before = state.enemies_of(unit).select(&:alive?).map(&:id)
        acted = try_cast(unit, state)
        acted ||= try_attack(unit, target, state)
        move(unit, target, state) unless acted
        award_on_kill(unit, before, state)
      end
      reconcile_dead(state)
    end

    # Free grid tiles held by units that died this tick (e.g. from an ability),
    # so movement/targeting don't treat corpses as blockers.
    def reconcile_dead(state)
      state.units.each do |u|
        next if u.alive?
        state.grid.vacate(u.x, u.y) if state.grid.occupant(u.x, u.y) == u.id
      end
    end

    # Apply damage-over-time from active statuses (bleed/poison/burn) at the top
    # of the tick, in id order, before units act. Flat true damage, min 1.
    def tick_statuses(state)
      state.living_in_order.each do |unit|
        next if unit.statuses.empty?
        unit.statuses.each do |s|
          dmg = [s["damage"].to_i, 1].max
          unit.take_damage(dmg)
          s["remaining"] -= 1
          @events << { tick: state.tick, type: "status", unit_id: unit.id,
                       effect: s["type"], damage: dmg,
                       target_health_after: unit.current_health,
                       target_shield_after: unit.barrier }
          break unless unit.alive?
        end
        unit.statuses.reject! { |s| s["remaining"] <= 0 }
        unless unit.alive?
          state.grid.vacate(unit.x, unit.y) if state.grid.occupant(unit.x, unit.y) == unit.id
          @events << { tick: state.tick, type: "death", unit_id: unit.id }
        end
      end
    end

    def regen_and_cooldowns(unit)
      unit.mana = [unit.mana + unit.stats[:mana_regen], unit.stats[:mana_cap]].min
      regenerate_health(unit)
      Buffs.tick(unit) # expire timed stat buffs (Blitz/Sustain/Ward)
      unit.disarmed_ticks -= 1 if unit.disarmed_ticks.positive? # Jail wears off
      unit.attack_cooldown -= 1 if unit.attack_cooldown.positive?
      unit.ability_cooldowns.each_key do |k|
        unit.ability_cooldowns[k] -= 1 if unit.ability_cooldowns[k].positive?
      end
    end

    # Tries abilities in the unit's priority order; casts the first castable one.
    def try_cast(unit, state)
      return false if silenced?(unit, state)

      unit.abilities.each do |ability_name|
        ability = Abilities::Registry.fetch(ability_name)
        next unless ability&.castable?(unit, state)

        @events.concat(ability.resolve(caster: unit, state: state, tick: state.tick).map(&:to_h))
        return true
      end
      false
    end

    # A unit is silenced (cannot cast) while any living enemy that carries a
    # silence aura (e.g. Nullification Orb) is within that enemy's aura radius.
    def silenced?(unit, state)
      state.enemies_of(unit).any? do |e|
        e.alive? && e.silence_aura.positive? &&
          Grid.manhattan(unit.position, e.position) <= e.silence_aura
      end
    end

    def try_attack(unit, target, state)
      return false if unit.disarmed? # Jailed: no basic attacks (abilities still fire)
      return false unless Grid.manhattan(unit.position, target.position) <= unit.stats[:attack_range]
      return false unless unit.attack_cooldown.zero?

      raw = unit.stats[:attack_damage]
      raw = [raw, target.stats[:attack_damage]].max if unit.scales_to_target # Scales of Power
      # Fellborn Blade: bonus vs targets with more max health than the wielder.
      raw += unit.bonus_vs_higher_max_health if unit.bonus_vs_higher_max_health.positive? &&
                                                 target.stats[:health] > unit.stats[:health]
      dmg = Damage.physical(raw: raw, attacker: unit, defender: target)
      target.take_damage(dmg)
      unit.attack_cooldown = unit.attack_cooldown_ticks(@tick_seconds)
      apply_lifesteal(unit, dmg)
      ramp_attack(unit) # Frenzy

      @events << { tick: state.tick, type: "attack", source_id: unit.id,
                   target_id: target.id, damage: dmg,
                   target_health_after: target.current_health,
                   target_shield_after: target.barrier }
      if target.alive?
        apply_on_hit(unit, target, state)
      else
        state.grid.vacate(target.x, target.y)
        @events << { tick: state.tick, type: "death", unit_id: target.id }
      end
      true
    end

    # Roster-modifier on-kill rewards: if this unit's action killed any enemy
    # that was alive before it acted, grant on_kill_mana per kill (capped).
    def award_on_kill(unit, before_ids, state)
      bonus = unit.modifiers["on_kill_mana"].to_f
      return if bonus.zero?
      kills = before_ids.count { |id| !state.find(id).alive? }
      return if kills.zero?
      unit.mana = [unit.mana + bonus * kills, unit.stats[:mana_cap]].min
    end

    # Weapon-driven on-hit statuses (e.g. bleed). Deterministic via the seeded PRNG.
    def apply_on_hit(attacker, target, state)
      attacker.on_hit.each do |effect|
        next unless state.prng.chance?(effect["chance"].to_f)

        applied = StatusEffects.apply(
          target, kind: effect["type"],
          damage: effect["damage"].to_i + attacker.dot_bonus_damage,       # Plaguebearer
          duration: effect["duration"].to_i + attacker.dot_bonus_duration,
          source_id: attacker.id
        )
        next unless applied # target immune (e.g. Absolute Resolve)

        @events << { tick: state.tick, type: "status_applied", unit_id: target.id,
                     effect: effect["type"], source_id: attacker.id }
      end
    end

    # Blade of Dromoz: heal the attacker for a fraction of damage dealt, capped
    # at max health. Silent (no event) — reflected in later state + snapshot.
    def apply_lifesteal(unit, dmg)
      return unless unit.lifesteal.positive? && unit.alive?

      heal = (dmg * unit.lifesteal).round
      return unless heal.positive?

      unit.current_health = [unit.current_health + heal, unit.stats[:health]].min
    end

    # Frenzy: permanently raise attack_damage by a fixed step per attack, up to a
    # total cap, for the rest of the battle.
    def ramp_attack(unit)
      step = unit.attack_gain_per_attack
      return unless step.positive? && unit.attack_gained < unit.attack_gain_cap

      gain = [step, unit.attack_gain_cap - unit.attack_gained].min
      unit.attack_gained += gain
      unit.stats[:attack_damage] += gain
    end

    def move(unit, target, state)
      steps = Movement.advance(unit, target, state.grid, @tick_seconds)
      steps.each do |s|
        @events << { tick: state.tick, type: "move", unit_id: unit.id,
                     from: s[:from], to: s[:to] }
      end
    end

    def build_output(state)
      alive_teams = state.teams_alive
      winner =
        if alive_teams.size == 1
          alive_teams.first
        elsif alive_teams.empty?
          "draw"
        else
          "timeout"
        end

      {
        winner: winner,
        duration_ticks: state.tick,
        tick_ms: @tick_ms,
        final_units: state.units.map { |u| unit_snapshot(u) },
        events: @events
      }
    end

    def unit_snapshot(u)
      { id: u.id, team: u.team, name: u.name, alive: u.alive?,
        current_health: u.current_health, max_health: u.stats[:health],
        mana: u.mana.round(2), position: u.position }
    end

    def symbolize(obj)
      case obj
      when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_sym] = symbolize(v) }
      when Array then obj.map { |v| symbolize(v) }
      else obj
      end
    end
  end
end
