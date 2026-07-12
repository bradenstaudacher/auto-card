require "rails_helper"

RSpec.describe "Api::V1 co-op", type: :request do
  def json = JSON.parse(response.body)

  it "creates a lobby with a room code and one player" do
    post "/api/v1/coop", params: { handle: "host" }, as: :json
    expect(response).to have_http_status(:created)
    expect(json["mode"]).to eq("two_player_coop")
    expect(json["status"]).to eq("lobby")
    expect(json["players"].size).to eq(1)
    expect(json.dig("me", "seat")).to eq(1)
    expect(json["current_round_data"]).to be_nil # no battle round until P2 joins
  end

  it "lets a second player join and starts preparation" do
    post "/api/v1/coop", params: { handle: "host" }, as: :json
    code = json["players"] && json.dig("me")
    room = JSON.parse(response.body) # capture
    room_code = GameSession.last.room_code

    post "/api/v1/coop/join", params: { room_code: room_code, handle: "guest" }, as: :json
    expect(response).to have_http_status(:ok)
    expect(json["status"]).to eq("preparation")
    expect(json["players"].size).to eq(2)
    expect(json.dig("me", "seat")).to eq(2)
    expect(json["current_round_data"]).to be_present
  end

  it "rejects an unknown room code" do
    post "/api/v1/coop/join", params: { room_code: "ZZZZ", handle: "x" }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "resolves the shared battle only after BOTH players lock in" do
    host = User.create!(handle: "h")
    guest = User.create!(handle: "g")
    session = RunOrchestrator.start_coop(user: host)
    RunOrchestrator.join_coop(room_code: session.room_code, user: guest)
    session.reload
    p1 = session.players.find_by(seat: 1)
    p2 = session.players.find_by(seat: 2)
    orch = RunOrchestrator.new(session)

    def two(player, x0)
      player.player_characters.order(:bench_position).first(2).map.with_index do |pc, i|
        { "player_character_id" => pc.id, "x" => x0 + i, "y" => 5 }
      end
    end

    orch.submit_placement(player: p1, placements: two(p1, 0))
    expect(session.reload.current_battle_round.resolved?).to be(false)

    orch.submit_placement(player: p2, placements: two(p2, 3))
    round = session.reload.current_battle_round
    expect(round).to be_resolved
    expect(round.reward_offers.count).to eq(2) # one per player
    expect(session.status).to eq("reward")
  end
end
