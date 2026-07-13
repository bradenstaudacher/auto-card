# Consumes an XP card (category "xp") to grant its XP to a champion. The card is
# destroyed on use — it's a one-shot consumable, not equipment. Validates
# ownership and that the card actually grants XP.
class ExperienceFeed
  Result = Struct.new(:ok, :errors) do
    def ok? = ok
  end

  def self.consume(card, character)
    new(card, character).consume
  end

  def initialize(card, character)
    @card = card
    @character = character
  end

  def consume
    errors = validate
    return Result.new(false, errors) if errors.any?

    ApplicationRecord.transaction do
      @character.add_xp!(amount)
      @card.destroy!
    end
    Result.new(true, [])
  end

  private

  def amount
    @card.card_template.rules["xp_grant"].to_i
  end

  def validate
    errors = []
    errors << "card and champion belong to different players" if @card.player_id != @character.player_id
    errors << "#{@card.name} does not grant XP" unless @card.category == "xp" && amount.positive?
    errors
  end
end
