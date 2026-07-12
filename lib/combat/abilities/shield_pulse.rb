module Combat
  module Abilities
    # Law support: heals the most-wounded ally in range for magic_power scaling.
    # Only castable when an injured ally exists, so it's never wasted.
    class ShieldPulse < Base
      def name      = "Shield Pulse"
      def mana_cost = 5
      def range     = 3
      def targeting = :ally

      # Restrict to injured allies within range; pick the most hurt.
      def choose_target(caster, state)
        injured = state.allies_of(caster).select do |u|
          u.alive? && u.current_health < u.stats[:health] &&
            Grid.manhattan(caster.position, u.position) <= range
        end
        injured.min_by { |u| [u.current_health, u.id] }
      end

      def resolve(caster:, state:, tick:)
        target = choose_target(caster, state)
        return [] unless target

        caster.mana -= mana_cost
        scale = caster.ability_params.dig(name, "power_scale") || 1.5
        heal = (caster.stats[:magic_power] * scale).round
        missing = target.stats[:health] - target.current_health
        applied = [heal, missing].min
        target.current_health += applied
        cleansed = StatusEffects.cleanse(target)

        events = [TimelineEvent.new(
          tick: tick, type: "cast", ability_name: name,
          source_id: caster.id, target_id: target.id,
          damage: 0, healing: applied, target_health_after: target.current_health,
          damage_type: "heal"
        )]
        if cleansed.any?
          events << TimelineEvent.new(tick: tick, type: "cleanse", unit_id: target.id, effects: cleansed)
        end
        events
      end
    end
  end
end
