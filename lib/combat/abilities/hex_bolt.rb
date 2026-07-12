module Combat
  module Abilities
    # Occult ranged nuke: single-target magic damage scaling on magic_power.
    class HexBolt < Base
      def name      = "Hex Bolt"
      def mana_cost = 3
      def range     = 4
      def targeting = :enemy

      def resolve(caster:, state:, tick:)
        target = choose_target(caster, state)
        return [] unless target

        caster.mana -= mana_cost
        scale = caster.ability_params.dig(name, "power_scale") || 1.6
        raw = (caster.stats[:magic_power] * scale).round
        dmg = Damage.magic(raw: raw, attacker: caster, defender: target)
        target.current_health -= dmg
        target.current_health = 0 if target.current_health.negative?

        events = [TimelineEvent.new(
          tick: tick, type: "cast", ability_name: name,
          source_id: caster.id, target_id: target.id,
          damage: dmg, target_health_after: target.current_health, damage_type: "magic"
        )]
        events << TimelineEvent.new(tick: tick, type: "death", unit_id: target.id) unless target.alive?
        events
      end
    end
  end
end
