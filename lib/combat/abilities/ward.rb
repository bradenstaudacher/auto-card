module Combat
  module Abilities
    # Generic (class-agnostic) protection: grants an absorb-shield BARRIER to the
    # caster and every adjacent ally. The barrier is a pool of extra HP that soaks
    # incoming damage before real health (see Unit#take_damage) and shows as the
    # grey segment on the health bar. Refresh-not-stack: recasting tops each
    # recipient's barrier back up to `amount` rather than stacking past it, so an
    # ability that recasts whenever mana refills stays bounded.
    class Ward < Base
      AMOUNT = 20

      def name      = "Ward"
      def mana_cost = 4
      def range     = 0
      def targeting = :self

      def resolve(caster:, state:, tick:)
        caster.mana -= mana_cost
        amount = caster.ability_params.dig(name, "amount") || AMOUNT

        recipients = [caster] + state.allies_of(caster).select do |a|
          a.alive? && Grid.manhattan(caster.position, a.position) <= 1
        end

        recipients.sort_by(&:id).map do |unit|
          unit.add_barrier(name, amount) # refresh own pool; stacks with other sources
          TimelineEvent.new(
            tick: tick, type: "cast", ability_name: name,
            source_id: caster.id, target_id: unit.id,
            damage: 0, healing: amount, target_health_after: unit.current_health,
            target_shield_after: unit.barrier, damage_type: "shield"
          )
        end
      end
    end
  end
end
