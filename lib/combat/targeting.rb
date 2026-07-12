module Combat
  # Target selection. Deterministic tie-breaking:
  #   1. nearest enemy by Manhattan distance
  #   2. then lowest current health
  #   3. then lowest deterministic id (string compare)
  module Targeting
    module_function

    def select(unit, enemies)
      living = enemies.select(&:alive?)
      return nil if living.empty?

      living.min_by do |enemy|
        [
          Grid.manhattan(unit.position, enemy.position),
          enemy.current_health,
          enemy.id
        ]
      end
    end
  end
end
