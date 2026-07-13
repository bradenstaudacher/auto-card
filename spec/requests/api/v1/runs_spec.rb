require "rails_helper"

RSpec.describe "Api::V1::Runs", type: :request do
  def json = JSON.parse(response.body)

  # Start a run and complete champion selection over HTTP, returning the run.
  def start_and_select(keys: %w[hollow_reaper ember_vanguard argent_truvate])
    post "/api/v1/runs", as: :json
    run_id = json["id"]
    post "/api/v1/runs/#{run_id}/select_champions", params: { champion_keys: keys }, as: :json
    json
  end

  describe "POST /api/v1/runs" do
    it "starts in champion selection and offers the champion pool" do
      post "/api/v1/runs", params: { handle: "req-tester" }, as: :json
      expect(response).to have_http_status(:created)
      expect(json["status"]).to eq("selection")
      expect(json["players"].first["roster"]).to eq([])
      expect(json["available_champions"].size).to eq(5)
    end

    it "select_champions builds the roster and enters preparation" do
      run = start_and_select
      expect(response).to have_http_status(:ok)
      expect(run["status"]).to eq("preparation")
      expect(run["players"].first["roster"].size).to eq(3)
      expect(run["current_round_data"]["player_slots"]).to eq(1)
    end
  end

  describe "the full single-player round over HTTP" do
    it "places, resolves server-side, and grants a reward" do
      run = start_and_select
      run_id = run["id"]
      player = run["players"].first
      reaper = player["roster"].find { |c| c["champion_key"] == "hollow_reaper" }

      post "/api/v1/runs/#{run_id}/placements",
           params: { player_id: player["id"],
                     placements: [{ player_character_id: reaper["id"], x: 1, y: 5 }] },
           as: :json
      expect(response).to have_http_status(:ok)
      round = json["current_round_data"]
      expect(round["status"]).to eq("resolved")
      expect(round["result"]["winner"]).to be_present
      expect(round["timeline"]).to be_an(Array)
      expect(json["status"]).to eq("reward")

      offer = json["reward_offers"].first
      card_id = offer["choices"].first["card_template_id"]
      post "/api/v1/runs/#{run_id}/rewards/#{offer['id']}/select",
           params: { card_template_id: card_id }, as: :json
      expect(response).to have_http_status(:ok)
      expect(json["current_round"]).to eq(2)
      expect(json["players"].first["tableau"].size).to eq(1)
    end
  end

  describe "placement validation" do
    it "returns 422 for an out-of-zone tile" do
      run = start_and_select
      pc = run["players"].first["roster"].first
      post "/api/v1/runs/#{run['id']}/placements",
           params: { player_id: run["players"].first["id"],
                     placements: [{ player_character_id: pc["id"], x: 7, y: 0 }] },
           as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["errors"].first).to match(/deployment zone/)
    end
  end

  describe "GET /api/v1/runs/:id" do
    it "404s for an unknown run" do
      get "/api/v1/runs/999999"
      expect(response).to have_http_status(:not_found)
    end

    it "self-heals a stuck trio of duplicates when the tableau is viewed" do
      # Simulate a trio that formed without the reward-select combine firing
      # (e.g. legacy data). Fetching the run during preparation should fuse it.
      session = start_prepared_run(User.create!(handle: "heal"))
      player = session.players.first
      cleave = CardTemplate.find_by(key: "card_cleave")
      3.times { player.player_cards.create!(card_template: cleave) }
      expect(player.player_cards.where(card_template: cleave).count).to eq(3)

      get "/api/v1/runs/#{session.id}"
      expect(response).to have_http_status(:ok)
      tableau = json["players"].first["tableau"]
      expect(tableau.size).to eq(1)
      expect(tableau.first["name"]).to eq("Cleave II")
    end
  end
end
