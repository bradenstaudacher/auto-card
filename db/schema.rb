# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_07_12_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "battle_rounds", force: :cascade do |t|
    t.bigint "game_session_id", null: false
    t.integer "round_number", null: false
    t.string "status", default: "pending", null: false
    t.jsonb "encounter_data", default: {}, null: false
    t.jsonb "placement_data", default: {}, null: false
    t.string "battle_seed"
    t.jsonb "result_data"
    t.jsonb "timeline"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_session_id", "round_number"], name: "index_battle_rounds_on_game_session_id_and_round_number", unique: true
    t.index ["game_session_id"], name: "index_battle_rounds_on_game_session_id"
  end

  create_table "card_templates", force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.string "category", null: false
    t.string "type_affinity"
    t.string "rarity", default: "common", null: false
    t.string "slot_type", null: false
    t.text "description"
    t.jsonb "valid_types", default: [], null: false
    t.jsonb "valid_subclasses", default: [], null: false
    t.jsonb "rules", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "tier", default: 1, null: false
    t.string "upgrades_to_key"
    t.index ["key"], name: "index_card_templates_on_key", unique: true
  end

  create_table "champion_templates", force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.string "type_key", null: false
    t.string "subclass"
    t.string "color"
    t.string "role"
    t.jsonb "base_stats", default: {}, null: false
    t.jsonb "slot_config", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "default_abilities", default: [], null: false
    t.index ["key"], name: "index_champion_templates_on_key", unique: true
  end

  create_table "game_sessions", force: :cascade do |t|
    t.string "mode", null: false
    t.string "status", default: "lobby", null: false
    t.integer "current_round", default: 1, null: false
    t.integer "max_rounds", default: 10, null: false
    t.string "seed", null: false
    t.string "room_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["room_code"], name: "index_game_sessions_on_room_code", unique: true
  end

  create_table "player_cards", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "card_template_id", null: false
    t.bigint "assigned_to_player_character_id"
    t.integer "assigned_slot_index"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_to_player_character_id"], name: "index_player_cards_on_assigned_to_player_character_id"
    t.index ["card_template_id"], name: "index_player_cards_on_card_template_id"
    t.index ["player_id"], name: "index_player_cards_on_player_id"
  end

  create_table "player_characters", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "champion_template_id", null: false
    t.jsonb "current_stats", default: {}, null: false
    t.jsonb "equipped_slots", default: {}, null: false
    t.integer "bench_position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "ability_priority", default: [], null: false
    t.index ["champion_template_id"], name: "index_player_characters_on_champion_template_id"
    t.index ["player_id"], name: "index_player_characters_on_player_id"
  end

  create_table "players", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "game_session_id", null: false
    t.integer "seat", default: 1, null: false
    t.integer "lives", default: 3, null: false
    t.boolean "ready", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_session_id", "seat"], name: "index_players_on_game_session_id_and_seat", unique: true
    t.index ["game_session_id"], name: "index_players_on_game_session_id"
    t.index ["user_id"], name: "index_players_on_user_id"
  end

  create_table "reward_offers", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "battle_round_id", null: false
    t.jsonb "choices", default: [], null: false
    t.bigint "selected_card_template_id"
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["battle_round_id"], name: "index_reward_offers_on_battle_round_id"
    t.index ["player_id", "battle_round_id"], name: "index_reward_offers_on_player_id_and_battle_round_id", unique: true
    t.index ["player_id"], name: "index_reward_offers_on_player_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "handle", null: false
    t.boolean "anonymous", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "battle_rounds", "game_sessions"
  add_foreign_key "player_cards", "card_templates"
  add_foreign_key "player_cards", "player_characters", column: "assigned_to_player_character_id", on_delete: :nullify
  add_foreign_key "player_cards", "players"
  add_foreign_key "player_characters", "champion_templates"
  add_foreign_key "player_characters", "players"
  add_foreign_key "players", "game_sessions"
  add_foreign_key "players", "users"
  add_foreign_key "reward_offers", "battle_rounds"
  add_foreign_key "reward_offers", "card_templates", column: "selected_card_template_id"
  add_foreign_key "reward_offers", "players"
end
