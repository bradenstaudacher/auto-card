module Combat
  module Abilities
    # Generic (class-agnostic) self-buff: raises the caster's attack_speed (a flat
    # add to attacks/second) for a duration, as a refresh-not-stack timed buff. The
    # faster cadence takes effect on the caster's next basic attack. `amount` and
    # `duration_ticks` come from the card.
    class Blitz < Base
      AMOUNT = 0.25
      DURATION_TICKS = 12 # 3 seconds

      def name      = "Blitz"
      def mana_cost = 3
      def range     = 0
      def targeting = :self

      def resolve(caster:, state:, tick:)
        caster.mana -= mana_cost
        amount   = caster.ability_params.dig(name, "amount") || AMOUNT
        duration = caster.ability_params.dig(name, "duration_ticks") || DURATION_TICKS
        Buffs.apply(caster, name: name, stat: "attack_speed", amount: amount, duration: duration)

        [TimelineEvent.new(
          tick: tick, type: "cast", ability_name: name,
          source_id: caster.id, target_id: caster.id,
          damage: 0, target_health_after: caster.current_health, damage_type: "buff"
        )]
      end
    end
  end
end
