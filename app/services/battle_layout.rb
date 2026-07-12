# Grid geometry + placement zones shared by the encounter builder and the
# placement validator. Allies deploy along the BOTTOM rows, monsters along the
# TOP rows (vertical orientation).
module BattleLayout
  ROWS = 6
  COLUMNS = 8

  ALLY_ROWS = (4..5)     # bottom rows — player deployment zone
  MONSTER_ROWS = (0..1)  # top rows — enemy zone

  module_function

  def grid
    { rows: ROWS, columns: COLUMNS }
  end

  def ally_zone?(x, y)
    (0...COLUMNS).include?(x) && ALLY_ROWS.include?(y)
  end
end
