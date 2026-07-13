require "rails_helper"

RSpec.describe ExperienceFeed do
  let(:template) do
    ChampionTemplate.create!(key: "t_feed", name: "Feedee", type_key: "Fury", subclass: "Warrior",
      base_stats: { "health" => 100 }, slot_config: {}, default_abilities: [])
  end
  let(:xp_card_tpl) do
    CardTemplate.create!(key: "c_tome", name: "Tome", category: "xp", slot_type: "consumable",
      rarity: "common", rules: { "xp_grant" => 50 })
  end
  let(:weapon_tpl) do
    CardTemplate.create!(key: "c_wpn", name: "Sword", category: "weapon", slot_type: "weapon",
      rarity: "common", rules: { "stat_modifiers" => { "attack_damage" => 3 } })
  end
  let(:user) { User.create!(handle: "u") }
  let(:session) { GameSession.create!(mode: "single_player", status: "preparation", current_round: 1, max_rounds: 10, seed: "s") }
  let(:player) { session.players.create!(user: user, seat: 1) }
  let(:pc) { player.player_characters.create!(champion_template: template, current_stats: {}, ability_priority: []) }

  it "grants the card's XP and consumes the card" do
    card = player.player_cards.create!(card_template: xp_card_tpl)
    result = ExperienceFeed.consume(card, pc)
    expect(result).to be_ok
    expect(pc.reload.xp).to eq(50)
    expect(PlayerCard.exists?(card.id)).to be(false)
  end

  it "rejects a non-XP card and leaves it intact" do
    card = player.player_cards.create!(card_template: weapon_tpl)
    result = ExperienceFeed.consume(card, pc)
    expect(result).not_to be_ok
    expect(result.errors.first).to match(/does not grant XP/)
    expect(PlayerCard.exists?(card.id)).to be(true)
  end
end
