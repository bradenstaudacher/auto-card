require "rails_helper"

RSpec.describe RunOrchestrator do
  let(:user) { User.create!(handle: "tester") }

  def place(orch, player, key, x, y, extra = [])
    pc = player.player_characters.joins(:champion_template)
               .find_by(champion_templates: { key: key })
    orch.submit_placement(player: player,
                          placements: [{ "player_character_id" => pc.id, "x" => x, "y" => y }] + extra)
  end

  describe ".start_single_player" do
    it "starts in champion selection with no roster yet" do
      session = described_class.start_single_player(user: user)
      expect(session.status).to eq("selection")
      expect(session.current_round).to eq(1)
      expect(session.players.first.player_characters.count).to eq(0)
    end

    it "select_champions creates the chosen roster and enters preparation" do
      session = described_class.start_single_player(user: user)
      result = described_class.new(session).select_champions(
        player: session.players.first, champion_keys: %w[ember_vanguard hollow_reaper argent_truvate]
      )
      expect(result).to be_ok
      expect(session.reload.status).to eq("preparation")
      expect(session.players.first.player_characters.count).to eq(3)
      expect(session.current_battle_round.encounter_data["monsters"]).to eq(%w[lesser_imp lesser_imp])
    end

    it "rejects a selection that isn't exactly three champions" do
      session = described_class.start_single_player(user: user)
      result = described_class.new(session).select_champions(
        player: session.players.first, champion_keys: %w[ember_vanguard hollow_reaper]
      )
      expect(result).not_to be_ok
      expect(result.errors.first).to match(/exactly 3/)
    end
  end

  describe "the round loop" do
    it "resolves a battle, offers rewards, and advances on selection" do
      session = start_prepared_run(user)
      player = session.players.first
      orch = described_class.new(session)

      result = place(orch, player, "ember_vanguard", 1, 5)
      expect(result).to be_ok

      round = session.reload.current_battle_round
      expect(round).to be_resolved
      expect(%w[allies monsters timeout draw]).to include(round.winner)
      expect(session.status).to eq("reward")

      offer = round.reward_offers.find_by(player: player)
      expect(offer.choices.size).to eq(round.victory? ? 3 : 2)

      chosen = offer.choices.first["card_template_id"]
      orch.select_reward(reward_offer: offer, card_template_id: chosen)

      expect(player.player_cards.count).to eq(1)
      expect(session.reload.current_round).to eq(2)
      expect(session.status).to eq("preparation")
    end

    it "re-simulates a resolved round to a byte-identical timeline (determinism through the stack)" do
      session = start_prepared_run(user)
      player = session.players.first
      place(described_class.new(session), player, "ember_vanguard", 1, 5)

      round = session.current_battle_round
      first_timeline = round.timeline.deep_dup

      # Re-run the exact same stored round through the engine.
      round.update!(status: "ready", timeline: nil, result_data: nil)
      BattleRunner.run!(round)
      expect(round.reload.timeline).to eq(first_timeline)
    end
  end

  describe "validation" do
    it "rejects placing more champions than the round allows" do
      session = start_prepared_run(user)
      player = session.players.first
      pcs = player.player_characters.limit(2).to_a
      result = described_class.new(session).submit_placement(
        player: player,
        placements: pcs.map.with_index { |pc, i| { "player_character_id" => pc.id, "x" => i, "y" => 5 } }
      )
      expect(result).not_to be_ok
      expect(result.errors.first).to match(/too many/)
    end
  end
end
