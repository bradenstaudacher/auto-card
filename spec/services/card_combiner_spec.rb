require "rails_helper"

RSpec.describe CardCombiner do
  let(:session) { RunOrchestrator.start_single_player(user: User.create!(handle: "c")) }
  let(:player) { session.players.first }
  let(:cleave) { CardTemplate.find_by(key: "card_cleave") }

  def owned_names = player.player_cards.reload.map { |c| c.card_template.name }

  it "fuses three identical cards into the next tier" do
    3.times { player.player_cards.create!(card_template: cleave) }
    described_class.combine!(player)
    expect(owned_names).to eq(["Cleave II"])
  end

  it "leaves fewer than three copies untouched" do
    2.times { player.player_cards.create!(card_template: cleave) }
    described_class.combine!(player)
    expect(owned_names).to eq(["Cleave", "Cleave"])
  end

  it "cascades three tiers (nine base -> one tier 3)" do
    9.times { player.player_cards.create!(card_template: cleave) }
    described_class.combine!(player)
    expect(owned_names).to eq(["Cleave III"])
  end

  it "combines across equipped and unequipped copies, unequipping as needed" do
    warrior = player.player_characters.joins(:champion_template)
                    .find_by(champion_templates: { key: "ember_vanguard" })
    equipped = player.player_cards.create!(card_template: cleave)
    CardAssignment.assign(equipped, warrior)
    2.times { player.player_cards.create!(card_template: cleave) }
    described_class.combine!(player)
    # 1 equipped + 2 unassigned = 3 total -> fuse into one Cleave II (unassigned)
    expect(owned_names).to eq(["Cleave II"])
    expect(player.player_cards.reload.first.assigned?).to be(false)
  end

  it "runs automatically when a duplicate reward is selected" do
    2.times { player.player_cards.create!(card_template: cleave) }
    round = session.current_battle_round
    round.update!(status: "resolved", result_data: { "winner" => "allies" })
    offer = round.reward_offers.create!(player: player, status: "pending",
      choices: [{ "card_template_id" => cleave.id, "name" => "Cleave" }])
    RewardRoller.select!(offer, cleave.id)
    expect(owned_names).to eq(["Cleave II"])
  end
end
