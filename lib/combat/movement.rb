module Combat
  # Simple deterministic pathing (A* deferred to post-MVP):
  #   - accumulate movement_speed * tick_seconds; each whole point = one step
  #   - step one tile toward target, preferring the axis with greater distance,
  #     horizontal first on ties
  #   - never enter an occupied tile; if the preferred step is blocked, try the
  #     other axis, then remaining adjacent tiles that reduce distance
  #   - if no progress is possible, stay put
  # Returns an array of {from:, to:} steps actually taken this tick.
  module Movement
    module_function

    def advance(unit, target, grid, tick_seconds)
      steps = []
      unit.move_progress += unit.stats[:movement_speed] * tick_seconds

      while unit.move_progress >= 1.0
        step = single_step(unit, target, grid)
        break unless step

        unit.move_progress -= 1.0
        steps << step
      end
      # Note: leftover fractional progress is intentionally retained so slow
      # units (speed*tick_seconds < 1) accumulate across ticks and still move.
      # The simulator only calls this when the unit is out of attack range.
      steps
    end

    # Chooses and applies one tile step. Returns {from:, to:} or nil.
    def single_step(unit, target, grid)
      dx = target.x - unit.x
      dy = target.y - unit.y

      candidates = []
      # Preferred axis: larger absolute distance; horizontal wins ties.
      if dx.abs >= dy.abs
        candidates << [unit.x + (dx <=> 0), unit.y] unless dx.zero?
        candidates << [unit.x, unit.y + (dy <=> 0)] unless dy.zero?
      else
        candidates << [unit.x, unit.y + (dy <=> 0)] unless dy.zero?
        candidates << [unit.x + (dx <=> 0), unit.y] unless dx.zero?
      end

      # Fallback: any adjacent tile that reduces Manhattan distance.
      current_dist = Grid.manhattan(unit.position, target.position)
      [[unit.x + 1, unit.y], [unit.x - 1, unit.y],
       [unit.x, unit.y + 1], [unit.x, unit.y - 1]].each do |nx, ny|
        next if candidates.include?([nx, ny])
        candidates << [nx, ny] if manhattan_xy(nx, ny, target) < current_dist
      end

      candidates.each do |nx, ny|
        next unless grid.in_bounds?(nx, ny)
        next if grid.occupied?(nx, ny)

        from = { x: unit.x, y: unit.y }
        grid.move(unit.id, unit.x, unit.y, nx, ny)
        unit.x = nx
        unit.y = ny
        return { from: from, to: { x: nx, y: ny } }
      end

      nil
    end

    def manhattan_xy(x, y, target)
      (x - target.x).abs + (y - target.y).abs
    end
  end
end
