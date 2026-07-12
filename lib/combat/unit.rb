module Combat
  # A combatant on the grid. Holds mutable battle state (position, health,
  # mana, cooldowns) plus immutable identity/stats. Teams are "allies" (all
  # player champions, including both seats in co-op) vs "monsters".
  class Unit
    STAT_KEYS = %i[
      health attack_damage magic_power armor shield
      mana_cap mana_regen movement_speed attack_range attack_speed
    ].freeze

    attr_reader :id, :team, :name, :type, :subclass, :stats, :abilities, :ability_params, :on_hit, :modifiers
    attr_accessor :x, :y, :current_health, :mana,
                  :attack_cooldown, :ability_cooldowns, :move_progress, :statuses

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
      # On-hit status appliers from equipped weapons, e.g.
      #   { "type" => "bleed", "chance" => 0.15, "damage" => 4, "duration" => 3 }
      @on_hit    = (spec[:on_hit] || []).map { |e| e.transform_keys(&:to_s) }
      @statuses  = []           # active damage-over-time effects
      # Roster-modifier combat effects, e.g. { "on_kill_mana" => 1 }.
      @modifiers = (spec[:modifiers] || {}).transform_keys(&:to_s)
    end

    def alive?
      @current_health > 0
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
      stats
    end
  end
end
