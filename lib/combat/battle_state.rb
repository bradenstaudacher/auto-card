module Combat
  # Holds all mutable battle state: the grid, every unit, the seeded PRNG, and
  # the current tick. Provides team queries used by targeting and abilities.
  class BattleState
    attr_reader :grid, :units, :prng
    attr_accessor :tick

    def initialize(grid:, units:, prng:)
      @grid = grid
      @units = units
      @prng = prng
      @tick = 0
      @by_id = units.each_with_object({}) { |u, h| h[u.id] = u }
      units.each { |u| @grid.place(u.id, u.x, u.y) }
    end

    def find(id)
      @by_id[id]
    end

    def living
      @units.select(&:alive?)
    end

    # Deterministic ordering for per-tick unit resolution.
    def living_in_order
      living.sort_by(&:id)
    end

    def allies_of(unit)
      @units.select { |u| u.team == unit.team && u.id != unit.id }
    end

    def enemies_of(unit)
      @units.select { |u| u.team != unit.team }
    end

    def teams_alive
      living.map(&:team).uniq
    end

    def over?
      teams_alive.size <= 1
    end
  end
end
