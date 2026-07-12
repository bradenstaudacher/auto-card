# Rolls post-battle reward choices for a player and applies their selection.
# Deterministic: seeded from the session seed + round + player so the same
# battle always yields the same offer. Rare odds climb in later rounds.
class RewardRoller
  def self.offer_for(player, battle_round)
    new(player, battle_round).offer!
  end

  def self.select!(reward_offer, card_template_id)
    new(reward_offer.player, reward_offer.battle_round).select!(reward_offer, card_template_id)
  end

  def initialize(player, battle_round)
    @player = player
    @round = battle_round
    @session = battle_round.game_session
  end

  # Creates (or returns existing) RewardOffer with N rolled choices.
  def offer!
    existing = @round.reward_offers.find_by(player: @player)
    return existing if existing

    count = choice_count
    return nil if count.zero?

    @round.reward_offers.create!(player: @player, choices: roll(count), status: "pending")
  end

  def select!(reward_offer, card_template_id)
    unless reward_offer.offered?(card_template_id)
      raise ArgumentError, "card #{card_template_id} was not offered"
    end

    ApplicationRecord.transaction do
      @player.player_cards.create!(card_template_id: card_template_id)
      reward_offer.update!(status: "selected", selected_card_template_id: card_template_id)
    end
    # Fuse any resulting trio of duplicates into an upgraded card; return the
    # names produced so the UI can celebrate the merge.
    CardCombiner.combine!(@player)
  end

  private

  def choice_count
    cfg = GameContent.single_player_round(@round.round_number)
    @round.victory? ? cfg["reward_choices_on_win"] : cfg["reward_choices_on_loss"]
  end

  def roll(count)
    prng = Combat::Prng.new("#{@session.seed}-r#{@round.round_number}-p#{@player.id}-reward")
    chosen = []
    picked_ids = []
    count.times do
      card = pick_card(prng, exclude: picked_ids)
      next unless card
      picked_ids << card.id
      chosen << card_choice(card)
    end
    chosen
  end

  def pick_card(prng, exclude:)
    rarity = weighted_rarity(prng)
    pool = card_pool.reject { |c| exclude.include?(c.id) }
    by_rarity = pool.select { |c| c.rarity == rarity }
    by_rarity = pool if by_rarity.empty? # fall back to any remaining
    return nil if by_rarity.empty?
    by_rarity[prng.rand_int(by_rarity.size)]
  end

  def weighted_rarity(prng)
    weights = GameContent.reward_rarity_weights.dup
    weights["rare"] = weights["rare"].to_i + @round.round_number # late-game rare boost
    total = weights.values.sum
    roll = prng.rand_int(total)
    cumulative = 0
    weights.each do |rarity, w|
      cumulative += w
      return rarity if roll < cumulative
    end
    "common"
  end

  # Sorted for deterministic indexing under the PRNG. Only base-tier cards are
  # offered; higher tiers are earned by combining three copies.
  def card_pool
    @card_pool ||= CardTemplate.base_tier.order(:key).to_a
  end

  def card_choice(card)
    { "card_template_id" => card.id, "key" => card.key, "name" => card.name,
      "category" => card.category, "rarity" => card.rarity,
      "type_affinity" => card.type_affinity, "valid_types" => card.valid_types,
      "slot_type" => card.slot_type, "tier" => card.tier, "description" => card.description }
  end
end
