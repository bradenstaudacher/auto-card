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

      until state.over? || state.tick >= @max_ticks
        state.tick += 1
        step(state)
      end

      build_output(state)
    end

    private

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
          unit.current_health -= dmg
          unit.current_health = 0 if unit.current_health.negative?
          s["remaining"] -= 1
          @events << { tick: state.tick, type: "status", unit_id: unit.id,
                       effect: s["type"], damage: dmg,
                       target_health_after: unit.current_health }
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
      unit.attack_cooldown -= 1 if unit.attack_cooldown.positive?
      unit.ability_cooldowns.each_key do |k|
        unit.ability_cooldowns[k] -= 1 if unit.ability_cooldowns[k].positive?
      end
    end

    # Tries abilities in the unit's priority order; casts the first castable one.
    def try_cast(unit, state)
      unit.abilities.each do |ability_name|
        ability = Abilities::Registry.fetch(ability_name)
        next unless ability&.castable?(unit, state)

        @events.concat(ability.resolve(caster: unit, state: state, tick: state.tick).map(&:to_h))
        return true
      end
      false
    end

    def try_attack(unit, target, state)
      return false unless Grid.manhattan(unit.position, target.position) <= unit.stats[:attack_range]
      return false unless unit.attack_cooldown.zero?

      dmg = Damage.physical(raw: unit.stats[:attack_damage], attacker: unit, defender: target)
      target.current_health -= dmg
      target.current_health = 0 if target.current_health.negative?
      unit.attack_cooldown = unit.attack_cooldown_ticks(@tick_seconds)

      @events << { tick: state.tick, type: "attack", source_id: unit.id,
                   target_id: target.id, damage: dmg,
                   target_health_after: target.current_health }
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

        StatusEffects.apply(target, kind: effect["type"], damage: effect["damage"],
                            duration: effect["duration"], source_id: attacker.id)
        @events << { tick: state.tick, type: "status_applied", unit_id: target.id,
                     effect: effect["type"], source_id: attacker.id }
      end
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
