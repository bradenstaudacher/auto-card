class AddUpgradeFieldsToCardTemplates < ActiveRecord::Migration[7.1]
  def change
    # tier 1 = base; combining 3 identical cards yields one card of the template
    # named by upgrades_to_key (which may itself upgrade further).
    add_column :card_templates, :tier, :integer, null: false, default: 1
    add_column :card_templates, :upgrades_to_key, :string
  end
end
