# Drives a run through its state machine: start -> preparation -> battle ->
# reward -> (advance) -> ... -> completed. Server-authoritative; controllers
# call these methods and never mutate session state directly.
class RunOrchestrator
  Result = Struct.new(:ok, :errors, :data) do
    def ok? = ok
  end

  # --- Entry point -----------------------------------------------------------
  CHAMPIONS_PER_RUN = 3

  def self.start_single_player(user:)
    session = GameSession.create!(
      mode: "single_player",
      status: "selection", # pick CHAMPIONS_PER_RUN champions before preparation
      current_round: 1,
      max_rounds: 10,
      seed: SecureRandom.hex(8)
    )
    session.players.create!(user: user, seat: 1)
    session
  end

  # Roster draft: create the chosen champions, then enter preparation. Validates
  # the count and that each key is a real, distinct champion template.
  def select_champions(player:, champion_keys:)
    return Result.new(false, ["selection already made"], nil) unless @session.status == "selection"

    keys = Array(champion_keys).uniq
    unless keys.size == CHAMPIONS_PER_RUN
      return Result.new(false, ["choose exactly #{CHAMPIONS_PER_RUN} champions"], nil)
    end

    templates = ChampionTemplate.where(key: keys)
    return Result.new(false, ["unknown champion in selection"], nil) unless templates.count == keys.size

    templates.each_with_index do |tpl, i|
      player.player_characters.create!(
        champion_template: tpl,
        current_stats: tpl.base_stats,
        ability_priority: Array(tpl.default_abilities),
        bench_position: i
      )
    end
    @session.update!(status: "preparation")
    ensure_current_round!
    Result.new(true, [], @session)
  end

  # --- Co-op --------------------------------------------------------------
  # Creates a co-op lobby (seat 1) and returns the session; a friend joins with
  # the room code. Battle begins once BOTH players lock in.
  def self.start_coop(user:)
    session = GameSession.create!(
      mode: "two_player_coop",
      status: "lobby",
      current_round: 1,
      max_rounds: 10,
      seed: SecureRandom.hex(8),
      room_code: generate_room_code
    )
    player = session.players.create!(user: user, seat: 1)
    build_roster(player)
    session
  end

  # Second player joins by room code; the run then enters preparation.
  def self.join_coop(room_code:, user:)
    session = GameSession.find_by(room_code: room_code.to_s.upcase, mode: "two_player_coop")
    return Result.new(false, ["no lobby with that code"], nil) unless session
    return Result.new(false, ["this lobby is full"], nil) if session.players.count >= 2
    return Result.new(false, ["this game already started"], nil) unless session.status == "lobby"

    player = session.players.create!(user: user, seat: 2)
    build_roster(player)
    session.update!(status: "preparation")
    new(session).ensure_current_round!
    Result.new(true, [], session)
  end

  def self.generate_room_code
    loop do
      code = Array.new(4) { ("A".."Z").to_a[SecureRandom.random_number(26)] }.join
      break code unless GameSession.exists?(room_code: code)
    end
  end

  def self.build_roster(player)
    ChampionTemplate.order(:key).each_with_index do |tpl, i|
      player.player_characters.create!(
        champion_template: tpl,
        current_stats: tpl.base_stats,
        ability_priority: Array(tpl.default_abilities),
        bench_position: i
      )
    end
  end

  def initialize(session)
    @session = session
  end

  # Create the BattleRound for the current round if it doesn't exist yet.
  def ensure_current_round!
    return @session.current_battle_round if @session.current_battle_round

    @session.battle_rounds.create!(
      round_number: @session.current_round,
      status: "pending",
      battle_seed: "#{@session.seed}-r#{@session.current_round}",
      encounter_data: EncounterBuilder.build(
        round_config, seed: "#{@session.seed}-r#{@session.current_round}-encounter"
      ),
      placement_data: carried_placement_data
    )
  end

  # Pre-fill the new round's board with the previous round's formation so players
  # don't redeploy from scratch — they can still adjust before locking in, and
  # readiness resets each round (advance! clears it). Empty on round 1. Trimmed
  # to this round's deploy limit in case it shrank.
  def carried_placement_data
    prev = @session.battle_rounds
                   .where("round_number < ?", @session.current_round)
                   .order(round_number: :desc).first
    return {} unless prev&.placement_data.present?

    limit = deploy_limit
    prev.placement_data.transform_values { |list| Array(list).first(limit) }
  end

  # Champions a player may deploy this round: fixed 2 in co-op, else the round's
  # player_slots.
  def deploy_limit
    return GameContent.rounds_config.dig("coop", "deployed_per_player") || 2 if @session.coop?

    round_config["player_slots"] || 1
  end

  # Encounter config for the current round. Co-op faces a bigger, tougher board
  # (two players) — extra monsters + higher stat scale.
  def round_config
    cfg = GameContent.single_player_round(@session.current_round)
    return cfg unless @session.coop?

    # Co-op faces ~1.5x the enemies. Bump draw counts (draw format) or duplicate
    # the front of the explicit list (legacy format), then raise the stat scale.
    bumped =
      if cfg["draw"]
        cfg.merge("draw" => cfg["draw"].transform_values { |n| (n * 1.5).ceil })
      elsif cfg["monsters"]
        monsters = cfg["monsters"]
        cfg.merge("monsters" => monsters + monsters.first((monsters.size / 2.0).ceil))
      else
        cfg
      end
    bumped.merge("stat_scale" => ((cfg["stat_scale"] || 1.0) * 1.3).round(3))
  end

  # --- Preparation -----------------------------------------------------------
  def submit_placement(player:, placements:)
    round = ensure_current_round!
    return Result.new(false, ["battle already resolved"], nil) if round.resolved?

    result = PlacementValidator.new(battle_round: round, player: player, placements: placements).validate
    return Result.new(false, result.errors, nil) unless result.valid?

    round.placement_data = round.placement_data.merge(player.seat.to_s => placements)
    round.save!
    player.update!(ready: true)

    resolve! if ready_to_resolve?
    Result.new(true, [], round.reload)
  end

  def ready_to_resolve?
    @session.players.where(ready: false).none?
  end

  # --- Battle + rewards ------------------------------------------------------
  def resolve!
    round = @session.current_battle_round
    @session.update!(status: "battle")
    BattleRunner.run!(round)
    ExperienceAward.grant!(round)
    @session.players.each { |p| RewardRoller.offer_for(p, round) }
    # Boss round grants no rewards -> nothing to select, advance straight on.
    advance! if no_rewards_pending?(round)
    round
  end

  def select_reward(reward_offer:, card_template_id:)
    combined = RewardRoller.select!(reward_offer, card_template_id)
    round = reward_offer.battle_round
    advance! if no_rewards_pending?(round)
    Result.new(true, [], { combined: combined })
  rescue ArgumentError => e
    Result.new(false, [e.message], nil)
  end

  # --- Advance ---------------------------------------------------------------
  def advance!
    round = @session.current_battle_round
    if @session.final_round? || lost_last_life?(round)
      @session.update!(status: "completed")
      return @session
    end

    @session.players.update_all(ready: false)
    @session.update!(current_round: @session.current_round + 1, status: "preparation")
    ensure_current_round!
    @session
  end

  private

  def no_rewards_pending?(round)
    round.reward_offers.where(status: "pending").none?
  end

  # Loss rule is "weaker rewards but continue", so a loss never ends the run in
  # MVP. Hook retained for future lives-based modes.
  def lost_last_life?(_round)
    false
  end
end
