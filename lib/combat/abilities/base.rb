module Combat
  module Abilities
    # Base class for ability definitions. Instances are stateless; all mutable
    # state lives on the caster/battle. Subclasses implement #resolve.
    class Base
      def name        = raise NotImplementedError
      def mana_cost   = raise NotImplementedError
      def range       = raise NotImplementedError
      def targeting   = :enemy # :enemy | :ally | :self | :area

      # Can this ability fire right now? Returns the chosen target unit (or the
      # caster for self-targeting) if castable, else nil.
      def choose_target(caster, state)
        return caster if targeting == :self

        pool = targeting == :ally ? state.allies_of(caster) : state.enemies_of(caster)
        candidates = pool.select do |u|
          u.alive? && Grid.manhattan(caster.position, u.position) <= range
        end
        return nil if candidates.empty?

        # Enemies: focus lowest current health, then lowest id (deterministic).
        candidates.min_by { |u| [u.current_health, u.id] }
      end

      def castable?(caster, state)
        return false unless caster.mana >= mana_cost
        return false unless (caster.ability_cooldowns[name]).zero?
        !choose_target(caster, state).nil?
      end

      # Performs the effect. Must return an array of TimelineEvent. Implementations
      # spend mana via caster and append events. `tick` is the current tick.
      def resolve(caster:, state:, tick:)
        raise NotImplementedError
      end
    end
  end
end
