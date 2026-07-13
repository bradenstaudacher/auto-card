module Combat
  module Abilities
    # Generic (class-agnostic) self-buff: raises the caster's health_regen (HP/sec)
    # for a duration, as a refresh-not-stack timed buff. The simulator's passive
    # regen picks up the higher rate on subsequent ticks. `amount` and
    # `duration_ticks` come from the card.
    class Sustain < Base
      AMOUNT = 5
      DURATION_TICKS = 12 # 3 seconds

      def name      = "Sustain"
      def mana_cost = 3
      def range     = 0
      def targeting = :self

      def resolve(caster:, state:, tick:)
        caster.mana -= mana_cost
        amount   = caster.ability_params.dig(name, "amount") || AMOUNT
        duration = caster.ability_params.dig(name, "duration_ticks") || DURATION_TICKS
        Buffs.apply(caster, name: name, stat: "health_regen", amount: amount, duration: duration)

        [TimelineEvent.new(
          tick: tick, type: "cast", ability_name: name,
          source_id: caster.id, target_id: caster.id,
          damage: 0, target_health_after: caster.current_health, damage_type: "buff"
        )]
      end
    end
  end
end
