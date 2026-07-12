# Server-authoritative validation of a seat's unit placement before a battle.
# Never trusts the client: checks ownership, slot count, zone, and tile
# collisions (including against the other seat's already-submitted placement in
# co-op). Returns an array of error strings — empty means valid.
class PlacementValidator
  Result = Struct.new(:errors) do
    def valid? = errors.empty?
  end

  # placements: [{ "player_character_id" => Integer, "x" => Integer, "y" => Integer }, ...]
  def initialize(battle_round:, player:, placements:)
    @round = battle_round
    @session = battle_round.game_session
    @player = player
    @placements = placements || []
  end

  def validate
    errors = []
    errors.concat(count_errors)
    errors.concat(ownership_errors)
    errors.concat(duplicate_errors)
    errors.concat(zone_errors)
    errors.concat(collision_errors)
    Result.new(errors)
  end

  private

  def allowed_slots
    if @session.coop?
      GameContent.rounds_config.dig("coop", "deployed_per_player")
    else
      GameContent.single_player_round(@round.round_number)["player_slots"]
    end
  end

  def count_errors
    return [] if @placements.size <= allowed_slots
    ["too many characters placed: #{@placements.size} (max #{allowed_slots})"]
  end

  def ownership_errors
    owned = @player.player_characters.pluck(:id).to_set
    @placements.reject { |p| owned.include?(p["player_character_id"]) }
               .map { |p| "character #{p['player_character_id']} does not belong to player" }
  end

  def duplicate_errors
    ids = @placements.map { |p| p["player_character_id"] }
    dups = ids.tally.select { |_, n| n > 1 }.keys
    dups.map { |id| "character #{id} placed more than once" }
  end

  def zone_errors
    @placements.reject { |p| BattleLayout.ally_zone?(p["x"], p["y"]) }
               .map { |p| "tile (#{p['x']},#{p['y']}) is outside the deployment zone" }
  end

  def collision_errors
    occupied = other_seat_tiles
    errors = []
    @placements.each do |p|
      tile = [p["x"], p["y"]]
      errors << "tile (#{p['x']},#{p['y']}) is occupied" if occupied.include?(tile)
      occupied << tile
    end
    errors
  end

  # Tiles already claimed by the other seat (co-op); empty in single-player.
  def other_seat_tiles
    @round.placement_data.reject { |seat, _| seat == @player.seat.to_s }
          .values.flatten
          .map { |p| [p["x"], p["y"]] }
          .to_set
  end
end
