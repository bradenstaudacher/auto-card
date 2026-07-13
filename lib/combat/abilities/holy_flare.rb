module Combat
  module Abilities
    # Holy ranged nuke. Magic damage scaling on magic_power; the type circle
    # already grants Holy its bonus vs Occult, so this shines against Occult foes.
    class HolyFlare < Base
      def name      = "Holy Flare"
      def mana_cost = 4
      def range     = 3
      def targeting = :enemy

      def resolve(caster:, state:, tick:)
        target = choose_target(caster, state)
        return [] unless target

        caster.mana -= mana_cost
        scale = caster.ability_params.dig(name, "power_scale") || 1.5
        raw = (caster.stats[:magic_power] * scale).round
        dmg = Damage.magic(raw: raw, attacker: caster, defender: target)
        target.take_damage(dmg)

        events = [TimelineEvent.new(
          tick: tick, type: "cast", ability_name: name,
          source_id: caster.id, target_id: target.id,
          damage: dmg, target_health_after: target.current_health,
          target_shield_after: target.barrier, damage_type: "magic"
        )]
        events << TimelineEvent.new(tick: tick, type: "death", unit_id: target.id) unless target.alive?
        events
      end
    end
  end
end
