module Combat
  module Abilities
    # Law control: locks an enemy down so it cannot BASIC-attack for a duration
    # (it can still cast and move). Duration is in ticks (the engine's time unit;
    # 4 ticks = 1s at the default 250ms tick). Refresh-not-stack — recasting takes
    # the longer remaining lockout. Targets the lowest-health in-range enemy.
    class Jail < Base
      DURATION_TICKS = 4 # 1 second

      def name      = "Jail"
      def mana_cost = 4
      def range     = 3
      def targeting = :enemy

      def resolve(caster:, state:, tick:)
        target = choose_target(caster, state)
        return [] unless target

        caster.mana -= mana_cost
        duration = caster.ability_params.dig(name, "duration_ticks") || DURATION_TICKS
        target.disarmed_ticks = [target.disarmed_ticks, duration].max

        [TimelineEvent.new(
          tick: tick, type: "status_applied", ability_name: name,
          source_id: caster.id, unit_id: target.id, target_id: target.id,
          effect: "disarm"
        )]
      end
    end
  end
end
