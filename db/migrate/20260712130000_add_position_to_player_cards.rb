class AddPositionToPlayerCards < ActiveRecord::Migration[7.1]
  def up
    # Player-controlled ordering of the tableau. Defaults to 0; the tableau
    # falls back to id order, so existing rows stay in insertion order until
    # the player drags one. Backfill to id keeps that order explicit.
    add_column :player_cards, :position, :integer, null: false, default: 0
    execute "UPDATE player_cards SET position = id"
  end

  def down
    remove_column :player_cards, :position
  end
end
