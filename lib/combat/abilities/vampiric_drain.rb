module Combat
  module Abilities
    # Drains an enemy for 25% of its CURRENT health (per locked design), healing
    # the caster for the amount actually dealt. Type advantage + shield apply,
    # then the result is clamped to [minimum_damage, maximum_damage]. The clamped
    # value is both the damage dealt and the healing granted.
    class VampiricDrain < Base
      MIN_DAMAGE = 5
      MAX_DAMAGE = 40

      def name      = "Vampiric Drain"
      def mana_cost = 3
      def range     = 3
      def targeting = :enemy

      def resolve(caster:, state:, tick:)
        target = choose_target(caster, state)
        return [] unless target

        caster.mana -= mana_cost

        pct = caster.ability_params.dig(name, "drain_pct") || 0.25
        min = caster.ability_params.dig(name, "min") || MIN_DAMAGE
        max = caster.ability_params.dig(name, "max") || MAX_DAMAGE
        raw = target.current_health * pct
        mitigated = Damage.magic(raw: raw, attacker: caster, defender: target)
        damage = mitigated.clamp(min, max)

        healing = target.take_damage(damage) # heal for HP actually drained (past any barrier)
        missing = caster.stats[:health] - caster.current_health
        applied_heal = [healing, missing].min
        caster.current_health += applied_heal

        cleansed = applied_heal.positive? ? StatusEffects.cleanse(caster) : []

        events = [TimelineEvent.new(
          tick: tick, type: "cast", ability_name: name,
          source_id: caster.id, target_id: target.id,
          damage: damage, healing: applied_heal,
          target_health_after: target.current_health,
          target_shield_after: target.barrier,
          source_health_after: caster.current_health,
          damage_type: "magic"
        )]
        events << TimelineEvent.new(tick: tick, type: "death", unit_id: target.id) unless target.alive?
        if cleansed.any?
          events << TimelineEvent.new(tick: tick, type: "cleanse", unit_id: caster.id, effects: cleansed)
        end
        events
      end
    end
  end
end
