# Plain-Ruby serializer producing the full client-facing state of a run. The
# React app renders entirely from this shape; the timeline is included once a
# round is resolved so the client can replay the battle.
class RunSerializer
  def self.call(session)
    new(session).as_json
  end

  def initialize(session)
    @session = session
  end

  def as_json
    {
      id: @session.id,
      mode: @session.mode,
      status: @session.status,
      room_code: @session.room_code,
      current_round: @session.current_round,
      max_rounds: @session.max_rounds,
      players: @session.players.order(:seat).map { |p| player_json(p) },
      current_round_data: round_json(@session.current_battle_round),
      reward_offers: reward_offers_json,
      available_champions: @session.status == "selection" ? available_champions_json : nil
    }
  end

  # The full champion pool offered at run start (status "selection").
  def available_champions_json
    ChampionTemplate.order(:key).map do |t|
      {
        key: t.key, name: t.name, type: t.type_key, subclass: t.subclass,
        color: t.color, role: t.role, base_stats: t.base_stats,
        slot_config: t.slot_config, default_abilities: t.default_abilities,
      }
    end
  end

  private

  def player_json(player)
    {
      id: player.id,
      seat: player.seat,
      lives: player.lives,
      ready: player.ready,
      roster: player.player_characters.includes(:champion_template, player_cards: :card_template)
                    .order(:bench_position).map { |pc| character_json(pc) },
      tableau: tableau_json(player)
    }
  end

  # Tableau cards, each annotated with how many copies of that template the
  # player owns (equipped + unequipped) so the UI can show combine progress
  # toward the 3-copy upgrade.
  def tableau_json(player)
    owned_counts = player.player_cards.group(:card_template_id).count
    player.tableau.map { |pc| player_card_json(pc, owned_counts[pc.card_template_id] || 1) }
  end

  def character_json(pc)
    t = pc.champion_template
    {
      id: pc.id,
      champion_key: t.key,
      name: t.name,
      type: t.type_key,
      subclass: t.subclass,
      color: t.color,
      role: t.role,
      base_stats: t.base_stats,
      effective_stats: effective_stats(pc),
      slot_config: pc.slot_config,
      level: pc.level,
      xp: pc.xp,
      xp_progress: pc.xp_progress,
      default_abilities: t.default_abilities,
      ability_priority: pc.ability_priority,
      abilities: abilities_json(pc),
      equipped: pc.player_cards.map { |c| equipped_card_json(c) }
    }
  end

  # Abilities the champion will cast, in priority order, with display metadata.
  def abilities_json(pc)
    available = Array(pc.champion_template.default_abilities) +
                pc.player_cards.select { |c| c.category == "ability" }.map(&:ability_name)
    available = available.uniq
    order = Array(pc.ability_priority).select { |n| available.include?(n) }
    order += (available - order)
    order.each_with_index.map do |name, i|
      meta = GameContent.ability(name) || {}
      {
        name: name,
        priority: i + 1,
        description: meta["description"],
        mana_cost: meta["mana_cost"],
        damage_type: meta["damage_type"],
        range: meta["range"],
        implemented: meta.fetch("implemented", false),
        is_default: Array(pc.champion_template.default_abilities).include?(name)
      }
    end
  end

  # Base stats + equipped stat_modifiers, so the modal reflects real combat stats.
  def effective_stats(pc)
    stats = pc.leveled_base_stats
    pc.player_cards.each do |c|
      (c.card_template.rules["stat_modifiers"] || {}).each do |k, delta|
        stats[k] = (stats[k] || 0) + delta
      end
    end
    stats
  end

  def equipped_card_json(c)
    t = c.card_template
    {
      player_card_id: c.id,
      card_template_id: t.id,
      name: t.name,
      category: t.category,
      slot_type: t.slot_type,
      rarity: t.rarity,
      type_affinity: t.type_affinity,
      tier: t.tier,
      description: t.description,
      assigned_slot_index: c.assigned_slot_index
    }
  end

  COMBINE_THRESHOLD = CardCombiner::THRESHOLD

  def player_card_json(pc, copies = 1)
    t = pc.card_template
    upgrades = t.upgrades_to_key.present?
    {
      id: pc.id,
      card_template_id: t.id,
      name: t.name,
      category: t.category,
      rarity: t.rarity,
      slot_type: t.slot_type,
      type_affinity: t.type_affinity,
      valid_types: t.valid_types,
      tier: t.tier,
      upgrades: upgrades,
      # Combine progress toward the next tier (only when an upgrade path exists).
      copies: copies,
      combine_threshold: upgrades ? COMBINE_THRESHOLD : nil,
      description: t.description,
      assigned_to_player_character_id: pc.assigned_to_player_character_id,
      assigned_slot_index: pc.assigned_slot_index
    }
  end

  def round_json(round)
    return nil unless round
    cfg = @session.single_player? ? GameContent.single_player_round(round.round_number) : nil
    {
      round_number: round.round_number,
      status: round.status,
      player_slots: cfg && cfg["player_slots"],
      boss: cfg && cfg["boss"] || false,
      grid: BattleLayout.grid,
      encounter: round.encounter_data,
      placement_data: round.placement_data,
      result: round.result_data,
      timeline: round.resolved? ? round.timeline : nil
    }
  end

  def reward_offers_json
    round = @session.current_battle_round
    return [] unless round
    round.reward_offers.map do |o|
      {
        id: o.id,
        player_id: o.player_id,
        status: o.status,
        choices: o.choices,
        selected_card_template_id: o.selected_card_template_id
      }
    end
  end
end
