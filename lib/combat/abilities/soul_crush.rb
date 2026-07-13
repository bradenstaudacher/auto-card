module Combat
  module Abilities
    # Death nuke dealing TRUE damage — ignores armor, shield, AND type advantage
    # by writing straight to health. Scales on magic_power so it grows into a
    # reliable anti-tank / anti-shield answer as the caster gears up (stacks with
    # other power sources for real depth).
    class SoulCrush < Base
      POWER_SCALE = 0.4

      def name      = "Soul Crush"
      def mana_cost = 3
      def range     = 3
      def targeting = :enemy

      def resolve(caster:, state:, tick:)
        target = choose_target(caster, state)
        return [] unless target

        caster.mana -= mana_cost
        scale = caster.ability_params.dig(name, "power_scale") || POWER_SCALE
        dmg = [(caster.stats[:magic_power] * scale).round, 1].max
        target.current_health -= dmg
        target.current_health = 0 if target.current_health.negative?

        events = [TimelineEvent.new(
          tick: tick, type: "cast", ability_name: name,
          source_id: caster.id, target_id: target.id,
          damage: dmg, target_health_after: target.current_health, damage_type: "true"
        )]
        events << TimelineEvent.new(tick: tick, type: "death", unit_id: target.id) unless target.alive?
        events
      end
    end
  end
end
