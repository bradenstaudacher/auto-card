module Combat
  # A combatant on the grid. Holds mutable battle state (position, health,
  # mana, cooldowns) plus immutable identity/stats. Teams are "allies" (all
  # player champions, including both seats in co-op) vs "monsters".
  class Unit
    STAT_KEYS = %i[
      health attack_damage magic_power armor resist
      mana_cap mana_regen movement_speed attack_range attack_speed health_regen
    ].freeze

    attr_reader :id, :team, :name, :type, :subclass, :stats, :abilities, :ability_params, :on_hit, :modifiers, :start_effects, :immunities, :silence_aura, :scales_to_target,
                :lifesteal, :bonus_vs_higher_max_health, :attack_gain_per_attack, :attack_gain_cap, :auras,
                :dot_bonus_damage, :dot_bonus_duration
    attr_accessor :attack_gained
    attr_accessor :x, :y, :current_health, :mana,
                  :attack_cooldown, :ability_cooldowns, :move_progress, :statuses, :heal_progress,
                  :buffs, :disarmed_ticks

    def initialize(spec)
      @id       = spec.fetch(:id)
      @team     = spec.fetch(:team)
      @name     = spec.fetch(:name)
      @type     = spec.fetch(:type)
      @subclass = spec[:subclass]
      @stats    = normalize_stats(spec.fetch(:stats))
      sorted = (spec[:abilities] || []).sort_by { |a| a[:priority] || 999 }
      @abilities = sorted.map { |a| a[:name] }
      # Per-ability tunables (e.g. damage_scale from an upgraded card), keyed by
      # ability name with stringified param keys so lookups are consistent.
      @ability_params = sorted.each_with_object({}) do |a, h|
        h[a[:name]] = (a[:params] || {}).transform_keys(&:to_s)
      end

      pos = spec.fetch(:position)
      @x = pos.fetch(:x)
      @y = pos.fetch(:y)

      @current_health   = @stats[:health]
      @mana             = 0.0
      @attack_cooldown  = 0     # ticks until next basic attack allowed
      @ability_cooldowns = Hash.new(0)
      @move_progress    = 0.0   # accumulates movement_speed * tick_seconds
      @heal_progress    = 0.0   # accumulates health_regen * tick_seconds; whole HP applied
      # On-hit status appliers from equipped weapons, e.g.
      #   { "type" => "bleed", "chance" => 0.15, "damage" => 4, "duration" => 3 }
      @on_hit    = (spec[:on_hit] || []).map { |e| e.transform_keys(&:to_s) }
      @statuses  = []           # active damage-over-time effects
      @buffs     = []           # active timed stat buffs (Blitz/Sustain/Ward)
      @disarmed_ticks = 0       # ticks remaining unable to basic-attack (Jail)
      @barriers  = {}           # absorb-shield HP pools keyed by source; soak damage before health
      # Roster-modifier combat effects, e.g. { "on_kill_mana" => 1 }.
      @modifiers = (spec[:modifiers] || {}).transform_keys(&:to_s)
      # One-time battle-start passives, e.g. { "adjacent_ally_shield" => 3 }.
      # Applied by the simulator before the first tick.
      @start_effects = (spec[:start_effects] || {}).transform_keys(&:to_s)
      # Status kinds this unit can never receive, e.g. ["burn","bleed"].
      @immunities = Array(spec[:immunities]).map(&:to_s)
      # Silence-aura radius (tiles): living enemies within this range cannot cast.
      @silence_aura = (spec[:silence_aura] || 0).to_i
      # Scales of Power: basic attacks borrow the target's attack_damage when it
      # exceeds the wielder's, so a weak unit hits with a strong foe's power.
      @scales_to_target = spec[:scales_to_target] ? true : false
      # Basic-attack modifiers from weapons/passives.
      @lifesteal = (spec[:lifesteal] || 0).to_f                       # heal fraction of dmg dealt
      @bonus_vs_higher_max_health = (spec[:bonus_vs_higher_max_health] || 0).to_i
      @attack_gain_per_attack = (spec[:attack_gain_per_attack] || 0).to_i # Frenzy ramp
      @attack_gain_cap = (spec[:attack_gain_cap] || 0).to_i
      @attack_gained = 0                                              # running Frenzy total
      # Battle-start auras this unit projects, e.g.
      #   { "stat" => "armor", "amount" => 3, "range" => 2, "target" => "ally" }
      @auras = (spec[:auras] || []).map { |a| a.transform_keys(&:to_s) }
      # Plaguebearer: extra DoT damage/duration for statuses THIS unit applies.
      @dot_bonus_damage = (spec[:dot_bonus_damage] || 0).to_i
      @dot_bonus_duration = (spec[:dot_bonus_duration] || 0).to_i
    end

    def alive?
      @current_health > 0
    end

    # Jailed: cannot perform basic attacks (abilities/movement still allowed).
    def disarmed?
      @disarmed_ticks.positive?
    end

    # Total absorb-shield HP across all sources (the grey bar).
    def barrier
      @barriers.values.sum
    end

    # Grant an absorb barrier from `source`. Barriers from DIFFERENT sources stack
    # (each is its own pool), but re-applying the SAME source refreshes rather than
    # stacks — it tops that source's pool back up to `amount`, so an ability that
    # recasts whenever mana refills stays bounded.
    def add_barrier(source, amount)
      @barriers[source] = [@barriers[source] || 0, amount.to_i].max
    end

    # Apply `amount` incoming damage: absorb barriers soak it first (in the order
    # they were granted), then any remainder reduces health (floored at 0). True
    # damage passes bypass_barrier: true to punch straight through the shield.
    # Returns the amount that actually reached health (drives lifesteal/drain).
    def take_damage(amount, bypass_barrier: false)
      remaining = amount.to_i
      unless bypass_barrier
        @barriers.each_key do |src|
          break if remaining <= 0
          absorbed = [@barriers[src], remaining].min
          @barriers[src] -= absorbed
          remaining -= absorbed
        end
        @barriers.reject! { |_, v| v <= 0 }
      end
      @current_health -= remaining
      @current_health = 0 if @current_health.negative?
      remaining
    end

    def immune?(kind)
      @immunities.include?(kind.to_s)
    end

    def position
      { x: @x, y: @y }
    end

    def mana_full?
      @mana >= @stats[:mana_cap]
    end

    # Attack cadence in ticks. attack_speed is attacks/second; the simulator
    # supplies tick_seconds. Minimum one tick between attacks.
    def attack_cooldown_ticks(tick_seconds)
      per_second = @stats[:attack_speed].to_f
      return 1 if per_second <= 0
      [(1.0 / (per_second * tick_seconds)).round, 1].max
    end

    private

    def normalize_stats(raw)
      stats = {}
      STAT_KEYS.each do |k|
        v = raw[k] || raw[k.to_s]
        stats[k] = v
      end
      stats[:attack_speed] ||= 1.0
      stats[:resist] ||= 0 # magic mitigation is optional; absent means none
      stats
    end
  end
end
