module Combat
  # Temporary stat buffs (e.g. Blitz attack_speed, Sustain health_regen, Ward
  # shield). Unlike DoT statuses these carry no damage — they add a flat amount
  # to a unit stat for a duration in TICKS, then revert it. Refresh-not-stack:
  # recasting the same-named buff resets its duration instead of stacking, so an
  # ability that recasts whenever mana refills stays capped at one instance.
  module Buffs
    module_function

    # Apply or refresh a buff. New buffs add `amount` to the stat immediately and
    # record it; an existing buff of the same name only extends its remaining
    # duration (amount unchanged, since a given card always carries one amount).
    def apply(unit, name:, stat:, amount:, duration:)
      existing = unit.buffs.find { |b| b["name"] == name }
      if existing
        existing["remaining"] = [existing["remaining"], duration.to_i].max
        return false
      end

      unit.stats[stat.to_sym] = (unit.stats[stat.to_sym] || 0) + amount
      unit.buffs << { "name" => name, "stat" => stat.to_s,
                      "amount" => amount, "remaining" => duration.to_i }
      true
    end

    # Decrement every buff by one tick; revert and drop any that expired. Returns
    # the names that expired (unused today, handy for timeline events later).
    def tick(unit)
      return [] if unit.buffs.empty?

      expired = unit.buffs.select { |b| (b["remaining"] -= 1) <= 0 }
      expired.each { |b| unit.stats[b["stat"].to_sym] -= b["amount"] }
      unit.buffs -= expired
      expired.map { |b| b["name"] }
    end
  end
end
