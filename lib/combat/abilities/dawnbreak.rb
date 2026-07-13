module Combat
  module Abilities
    # Holy AoE nuke + ward. Sears the primary target and every enemy within one
    # tile of it for magic damage (power_scale * magic_power), then hardens each
    # ally within one tile of the caster with an absorb barrier (grey shield)
    # of (shield_scale * magic_power) that soaks damage. The type circle
    # already grants Holy its edge vs Occult, so the damage shines there.
    class Dawnbreak < Base
      POWER_SCALE  = 1.3
      SHIELD_SCALE = 0.5

      def name      = "Dawnbreak"
      def mana_cost = 5
      def range     = 3
      def targeting = :enemy

      def resolve(caster:, state:, tick:)
        primary = choose_target(caster, state)
        return [] unless primary

        caster.mana -= mana_cost
        power_scale  = caster.ability_params.dig(name, "power_scale") || POWER_SCALE
        shield_scale = caster.ability_params.dig(name, "shield_scale") || SHIELD_SCALE
        raw = (caster.stats[:magic_power] * power_scale).round

        events = []

        # Damage: primary + enemies adjacent to it, deterministic id order.
        victims = state.enemies_of(caster).select do |e|
          e.alive? && Grid.manhattan(primary.position, e.position) <= 1
        end
        victims |= [primary]
        victims.sort_by(&:id).each do |victim|
          dmg = Damage.magic(raw: raw, attacker: caster, defender: victim)
          victim.take_damage(dmg)
          events << TimelineEvent.new(
            tick: tick, type: "cast", ability_name: name,
            source_id: caster.id, target_id: victim.id,
            damage: dmg, target_health_after: victim.current_health,
            target_shield_after: victim.barrier, damage_type: "magic"
          )
          events << TimelineEvent.new(tick: tick, type: "death", unit_id: victim.id) unless victim.alive?
        end

        # Ward: allies adjacent to the caster gain a grey absorb barrier. Refreshes
        # its own pool on recast; stacks on top of barriers from other sources.
        ward = (caster.stats[:magic_power] * shield_scale).round
        if ward.positive?
          allies = state.allies_of(caster).select do |a|
            a.alive? && a.id != caster.id && Grid.manhattan(caster.position, a.position) <= 1
          end
          allies.sort_by(&:id).each do |ally|
            ally.add_barrier(name, ward)
            events << TimelineEvent.new(
              tick: tick, type: "cast", ability_name: name,
              source_id: caster.id, target_id: ally.id,
              damage: 0, healing: ward, target_health_after: ally.current_health,
              target_shield_after: ally.barrier, damage_type: "shield"
            )
          end
        end

        events
      end
    end
  end
end
