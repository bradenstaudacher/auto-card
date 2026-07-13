# Equips / unequips a PlayerCard to a PlayerCharacter with server-side
# validation (ownership, slot capacity, type/subclass restrictions). Ability
# cards additionally maintain the character's ability_priority order.
class CardAssignment
  Result = Struct.new(:ok, :errors) do
    def ok? = ok
  end

  # slot_type => champion slot_config key
  SLOT_CONFIG_KEY = {
    "weapon" => "weapon_slots",
    "equipment" => "equipment_slots",
    "passive" => "passive_slots",
    "ability" => "ability_slots",
  }.freeze

  def self.assign(player_card, character)
    new.assign(player_card, character)
  end

  def self.unassign(player_card)
    new.unassign(player_card)
  end

  def assign(card, character)
    errors = validate(card, character)
    return Result.new(false, errors) if errors.any?

    ApplicationRecord.transaction do
      # If moving from another character, tidy that character's ability order.
      remove_from_ability_order(card) if card.assigned?

      slot_type = card.card_template.slot_type
      used = character.player_cards.where.not(id: card.id)
                      .joins(:card_template).where(card_templates: { slot_type: slot_type }).count

      card.update!(assigned_to_player_character_id: character.id, assigned_slot_index: used)

      if card.category == "ability"
        order = Array(character.ability_priority)
        order << card.ability_name unless order.include?(card.ability_name)
        character.update!(ability_priority: order)
      end
    end
    Result.new(true, [])
  end

  def unassign(card)
    return Result.new(true, []) unless card.assigned?
    ApplicationRecord.transaction do
      remove_from_ability_order(card)
      card.update!(assigned_to_player_character_id: nil, assigned_slot_index: nil)
    end
    Result.new(true, [])
  end

  private

  def validate(card, character)
    t = card.card_template
    errors = []

    if card.player_id != character.player_id
      errors << "card and champion belong to different players"
    end

    if t.slot_type == "roster_modifier"
      errors << "#{t.name} is a roster-wide modifier and isn't equipped to a single champion"
      return errors
    end

    config_key = SLOT_CONFIG_KEY[t.slot_type]
    unless config_key
      errors << "unknown slot type #{t.slot_type}"
      return errors
    end

    capacity = character.slot_count(config_key)
    used = character.player_cards.where.not(id: card.id)
                    .joins(:card_template).where(card_templates: { slot_type: t.slot_type }).count
    errors << "no open #{t.slot_type} slot on #{character.champion_template.name}" if used >= capacity

    if t.valid_types.present? && !t.valid_types.include?(character.type_key)
      errors << "#{t.name} can't be used by #{character.type_key} champions"
    end
    if t.valid_subclasses.present? && !t.valid_subclasses.include?(character.champion_template.subclass)
      errors << "#{t.name} can't be used by the #{character.champion_template.subclass} subclass"
    end

    errors
  end

  def remove_from_ability_order(card)
    return unless card.category == "ability" && card.assigned?
    character = card.assigned_character
    return unless character

    name = card.ability_name
    # Keep the ability if a default or another equipped card still grants it.
    still_available =
      Array(character.champion_template.default_abilities).include?(name) ||
      character.player_cards.where.not(id: card.id)
               .joins(:card_template)
               .where(card_templates: { category: "ability" })
               .any? { |pc| pc.ability_name == name }
    return if still_available

    order = Array(character.ability_priority)
    order.delete(name)
    character.update!(ability_priority: order)
  end
end
