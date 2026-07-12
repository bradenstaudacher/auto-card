module Combat
  # Configurable type-advantage circle. Each attacker type deals bonus damage
  # to exactly one defender type:
  #   Holy   > Occult
  #   Occult > Death
  #   Death  > Fury
  #   Fury   > Law
  #   Law    > Holy
  # Applied to BOTH basic attacks and spell damage (per locked design).
  module TypeChart
    TYPES = %w[Occult Holy Law Fury Death].freeze

    ADVANTAGE = {
      "Holy"   => "Occult",
      "Occult" => "Death",
      "Death"  => "Fury",
      "Fury"   => "Law",
      "Law"    => "Holy"
    }.freeze

    ADVANTAGE_MULTIPLIER = 1.25
    NEUTRAL_MULTIPLIER   = 1.0

    module_function

    # Multiplier applied to raw damage before mitigation.
    def multiplier(attacker_type, defender_type)
      return NEUTRAL_MULTIPLIER if attacker_type.nil? || defender_type.nil?
      ADVANTAGE[attacker_type] == defender_type ? ADVANTAGE_MULTIPLIER : NEUTRAL_MULTIPLIER
    end

    def advantage?(attacker_type, defender_type)
      ADVANTAGE[attacker_type] == defender_type
    end
  end
end
