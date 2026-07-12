class CreateCoreSchema < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :handle, null: false
      t.boolean :anonymous, null: false, default: true
      t.timestamps
    end

    create_table :game_sessions do |t|
      t.string :mode, null: false            # single_player | two_player_coop
      t.string :status, null: false, default: "lobby" # lobby|preparation|battle|reward|completed
      t.integer :current_round, null: false, default: 1
      t.integer :max_rounds, null: false, default: 10
      t.string :seed, null: false
      t.string :room_code
      t.timestamps
    end
    add_index :game_sessions, :room_code, unique: true

    create_table :players do |t|
      t.references :user, null: false, foreign_key: true
      t.references :game_session, null: false, foreign_key: true
      t.integer :seat, null: false, default: 1   # 1 or 2 (co-op)
      t.integer :lives, null: false, default: 3
      t.boolean :ready, null: false, default: false
      t.timestamps
    end
    add_index :players, %i[game_session_id seat], unique: true

    # Content templates (seeded from config/game/*.yml).
    create_table :champion_templates do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.string :type_key, null: false
      t.string :subclass
      t.string :color
      t.string :role
      t.jsonb :base_stats, null: false, default: {}
      t.jsonb :slot_config, null: false, default: {}
      t.timestamps
    end
    add_index :champion_templates, :key, unique: true

    create_table :card_templates do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.string :category, null: false        # ability|weapon|equipment|passive|modifier
      t.string :type_affinity
      t.string :rarity, null: false, default: "common"
      t.string :slot_type, null: false       # ability|weapon|equipment|passive|roster_modifier
      t.text :description
      t.jsonb :valid_types, null: false, default: []
      t.jsonb :valid_subclasses, null: false, default: []
      t.jsonb :rules, null: false, default: {} # stat_modifiers, combat_effects, ability_name, etc.
      t.timestamps
    end
    add_index :card_templates, :key, unique: true

    create_table :player_characters do |t|
      t.references :player, null: false, foreign_key: true
      t.references :champion_template, null: false, foreign_key: true
      t.jsonb :current_stats, null: false, default: {}
      t.jsonb :equipped_slots, null: false, default: {} # slot_type => [player_card_id,...]
      t.integer :bench_position
      t.timestamps
    end

    create_table :player_cards do |t|
      t.references :player, null: false, foreign_key: true
      t.references :card_template, null: false, foreign_key: true
      t.bigint :assigned_to_player_character_id
      t.integer :assigned_slot_index
      t.timestamps
    end
    add_index :player_cards, :assigned_to_player_character_id
    add_foreign_key :player_cards, :player_characters,
                    column: :assigned_to_player_character_id, on_delete: :nullify

    create_table :battle_rounds do |t|
      t.references :game_session, null: false, foreign_key: true
      t.integer :round_number, null: false
      t.string :status, null: false, default: "pending" # pending|ready|resolved
      t.jsonb :encounter_data, null: false, default: {}
      t.jsonb :placement_data, null: false, default: {}  # keyed by seat
      t.string :battle_seed
      t.jsonb :result_data
      t.jsonb :timeline
      t.timestamps
    end
    add_index :battle_rounds, %i[game_session_id round_number], unique: true

    create_table :reward_offers do |t|
      t.references :player, null: false, foreign_key: true
      t.references :battle_round, null: false, foreign_key: true
      t.jsonb :choices, null: false, default: []
      t.bigint :selected_card_template_id
      t.string :status, null: false, default: "pending" # pending|selected
      t.timestamps
    end
    add_index :reward_offers, %i[player_id battle_round_id], unique: true
    add_foreign_key :reward_offers, :card_templates,
                    column: :selected_card_template_id
  end
end
