module Combat
  # Damage-over-time status effects (bleed / poison / burn). All share one
  # mechanic — flat true damage each tick for a duration — differing only in
  # label + color. Any healing cleanses ALL statuses on the healed unit.
  module StatusEffects
    KINDS = %w[bleed poison burn].freeze

    module_function

    # Adds (or refreshes) a status on the target. Refresh takes the longer
    # remaining duration and the higher per-tick damage so stacks don't stall.
    def apply(unit, kind:, damage:, duration:, source_id:)
      return nil if unit.immune?(kind)

      existing = unit.statuses.find { |s| s["type"] == kind }
      if existing
        existing["remaining"] = [existing["remaining"], duration].max
        existing["damage"] = [existing["damage"], damage].max
      else
        unit.statuses << { "type" => kind, "damage" => damage.to_i,
                           "remaining" => duration.to_i, "source_id" => source_id }
      end
    end

    # Removes every status. Returns the kinds cleared (for a timeline event).
    def cleanse(unit)
      cleared = unit.statuses.map { |s| s["type"] }
      unit.statuses = []
      cleared
    end

    def active?(unit)
      unit.statuses.any?
    end
  end
end
