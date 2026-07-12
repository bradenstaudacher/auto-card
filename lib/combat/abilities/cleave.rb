module Combat
  module Abilities
    # Fury melee strike: hits the primary target plus every enemy within one
    # tile of it for physical damage scaling on the caster's attack_damage.
    class Cleave < Base
      DAMAGE_SCALE = 1.5

      def name      = "Cleave"
      def mana_cost = 4
      def range     = 1
      def targeting = :enemy

      def resolve(caster:, state:, tick:)
        primary = choose_target(caster, state)
        return [] unless primary

        caster.mana -= mana_cost
        scale = caster.ability_params.dig(name, "damage_scale") || DAMAGE_SCALE
        raw = (caster.stats[:attack_damage] * scale).round

        victims = state.enemies_of(caster).select do |e|
          e.alive? && Grid.manhattan(primary.position, e.position) <= 1
        end
        victims |= [primary]

        events = []
        victims.sort_by(&:id).each do |victim|
          dmg = Damage.physical(raw: raw, attacker: caster, defender: victim)
          victim.current_health -= dmg
          victim.current_health = 0 if victim.current_health.negative?
          events << TimelineEvent.new(
            tick: tick, type: "cast", ability_name: name,
            source_id: caster.id, target_id: victim.id,
            damage: dmg, target_health_after: victim.current_health,
            damage_type: "physical"
          )
          events << TimelineEvent.new(tick: tick, type: "death", unit_id: victim.id) unless victim.alive?
        end
        events
      end
    end
  end
end
