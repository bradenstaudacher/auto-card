class AddAbilityPriorityToPlayerCharacters < ActiveRecord::Migration[7.1]
  def change
    # Ordered ability names (defaults + equipped ability cards) defining cast
    # priority. Editable via the character modal's reorder UI.
    add_column :player_characters, :ability_priority, :jsonb, null: false, default: []
  end
end
