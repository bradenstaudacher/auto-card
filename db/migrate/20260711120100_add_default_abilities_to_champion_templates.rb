class AddDefaultAbilitiesToChampionTemplates < ActiveRecord::Migration[7.1]
  def change
    # Signature abilities a champion enters battle with before any rewards.
    add_column :champion_templates, :default_abilities, :jsonb, null: false, default: []
  end
end
