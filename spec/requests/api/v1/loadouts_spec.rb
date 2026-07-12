require "rails_helper"

RSpec.describe "Api::V1 loadouts", type: :request do
  def json = JSON.parse(response.body)

  let(:session) { RunOrchestrator.start_single_player(user: User.create!(handle: "loadout")) }
  let(:player) { session.players.first }
  let(:warrior) do
    player.player_characters.joins(:champion_template).find_by(champion_templates: { key: "ember_vanguard" })
  end
  let(:blade) { player.player_cards.create!(card_template: CardTemplate.find_by(key: "card_serrated_blade")) }

  def char_json(body, key)
    body["players"].first["roster"].find { |c| c["champion_key"] == key }
  end

  it "equips a weapon and reflects it in effective_stats" do
    base = warrior.champion_template.base_stats["attack_damage"]
    post "/api/v1/runs/#{session.id}/player_cards/#{blade.id}/assign",
         params: { player_character_id: warrior.id }, as: :json
    expect(response).to have_http_status(:ok)
    c = char_json(json, "ember_vanguard")
    expect(c["effective_stats"]["attack_damage"]).to eq(base + 4)
    expect(c["equipped"].map { |e| e["name"] }).to include("Serrated Blade")
  end

  it "rejects a card the champion's subclass can't use" do
    alch = player.player_characters.joins(:champion_template).find_by(champion_templates: { key: "violet_alchemist" })
    post "/api/v1/runs/#{session.id}/player_cards/#{blade.id}/assign",
         params: { player_character_id: alch.id }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(json["errors"].join).to match(/slot|subclass/i)
  end

  it "adds an equipped ability to the priority order and reorders it" do
    reaper = player.player_characters.joins(:champion_template).find_by(champion_templates: { key: "hollow_reaper" })
    cleave = player.player_cards.create!(card_template: CardTemplate.find_by(key: "card_cleave"))
    # Reaper has 1 ability slot; default is Vampiric Drain. Cleave requires Fury,
    # so use the Warrior which allows it and has an open ability slot.
    post "/api/v1/runs/#{session.id}/player_cards/#{cleave.id}/assign",
         params: { player_character_id: warrior.id }, as: :json
    expect(response).to have_http_status(:ok)
    order = char_json(json, "ember_vanguard")["ability_priority"]
    expect(order).to include("Cleave")

    patch "/api/v1/runs/#{session.id}/player_characters/#{warrior.id}/ability_order",
          params: { order: order.reverse }, as: :json
    expect(response).to have_http_status(:ok)
    expect(char_json(json, "ember_vanguard")["ability_priority"]).to eq(order.reverse)
    reaper # referenced to silence unused warning
  end

  it "unequips a card" do
    post "/api/v1/runs/#{session.id}/player_cards/#{blade.id}/assign",
         params: { player_character_id: warrior.id }, as: :json
    post "/api/v1/runs/#{session.id}/player_cards/#{blade.id}/unassign", as: :json
    expect(response).to have_http_status(:ok)
    expect(char_json(json, "ember_vanguard")["equipped"]).to be_empty
  end
end
