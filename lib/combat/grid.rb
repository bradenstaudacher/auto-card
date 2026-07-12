module Combat
  # Rectangular battle grid. Tracks tile occupancy by unit id. Coordinates are
  # {x, y} with x = column (0..columns-1), y = row (0..rows-1).
  class Grid
    attr_reader :rows, :columns

    def initialize(rows:, columns:)
      @rows = rows
      @columns = columns
      @occupied = {} # [x, y] => unit_id
    end

    def in_bounds?(x, y)
      x >= 0 && x < columns && y >= 0 && y < rows
    end

    def occupied?(x, y)
      @occupied.key?([x, y])
    end

    def occupant(x, y)
      @occupied[[x, y]]
    end

    def place(unit_id, x, y)
      @occupied[[x, y]] = unit_id
    end

    def vacate(x, y)
      @occupied.delete([x, y])
    end

    # Move a unit's occupancy marker.
    def move(unit_id, from_x, from_y, to_x, to_y)
      vacate(from_x, from_y)
      place(unit_id, to_x, to_y)
    end

    def self.manhattan(a, b)
      (a[:x] - b[:x]).abs + (a[:y] - b[:y]).abs
    end
  end
end
