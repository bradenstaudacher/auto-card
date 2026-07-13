class AddLevelToPlayerCharacters < ActiveRecord::Migration[7.1]
  def change
    add_column :player_characters, :level, :integer, default: 1, null: false
    add_column :player_characters, :xp, :integer, default: 0, null: false
  end
end
