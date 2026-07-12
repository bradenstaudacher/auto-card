# Single source of truth for reading data-driven content from config/game/*.yml.
# Used by seeds (to upsert templates) and by services (EncounterBuilder reads
# monsters directly since they are not persisted as templates).
module GameContent
  DIR = Rails.root.join("config", "game")

  module_function

  def champions
    load_file("champions.yml").fetch("champions")
  end

  def monsters
    load_file("monsters.yml").fetch("monsters")
  end

  def cards
    load_file("cards.yml").fetch("cards")
  end

  def monster(key)
    monsters.find { |m| m["key"] == key } or raise KeyError, "unknown monster #{key}"
  end

  def abilities
    load_file("abilities.yml").fetch("abilities")
  end

  def ability(name)
    abilities.find { |a| a["name"] == name }
  end

  def rounds_config
    load_file("rounds.yml")
  end

  def single_player_round(round_number)
    rounds_config.fetch("single_player").find { |r| r["round"] == round_number } or
      raise KeyError, "no config for round #{round_number}"
  end

  def reward_rarity_weights
    rounds_config.fetch("reward_rarity_weights")
  end

  def load_file(name)
    YAML.load_file(DIR.join(name))
  end
end
