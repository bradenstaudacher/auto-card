module Combat
  # Damage resolution: type advantage applied to raw damage, then flat
  # mitigation (armor for physical, resist for magic), floored at 1.
  #
  #   physical_taken = max(1, round(raw * type_mult) - armor)
  #   magic_taken    = max(1, round(raw * type_mult) - resist)
  module Damage
    module_function

    # Returns the integer damage actually applied to the target (before any
    # ability-level min/max caps, which the ability applies to this result).
    def physical(raw:, attacker:, defender:)
      mult = TypeChart.multiplier(attacker.type, defender.type)
      amplified = (raw * mult).round
      [amplified - defender.stats[:armor], 1].max
    end

    def magic(raw:, attacker:, defender:)
      mult = TypeChart.multiplier(attacker.type, defender.type)
      amplified = (raw * mult).round
      [amplified - defender.stats[:resist], 1].max
    end
  end
end
