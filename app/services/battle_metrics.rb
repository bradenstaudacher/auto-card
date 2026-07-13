# Derives per-unit performance from a resolved battle timeline: damage dealt,
# healing given to allies, and kills. Pure function of the events + a team
# lookup, so it's deterministic and testable in isolation. Feeds XP awards.
class BattleMetrics
  # events: array of event hashes (string keys, as persisted on the round).
  # team_of: ->(unit_id) { "allies" | "monsters" | nil }
  def self.compute(events, team_of)
    new(events, team_of).compute
  end

  def initialize(events, team_of)
    @events = events
    @team_of = team_of
  end

  def compute
    metrics = Hash.new { |h, k| h[k] = { "damage_dealt" => 0, "healing_done" => 0, "kills" => 0 } }
    last_damager = {} # unit_id -> id of whoever last dealt it damage

    @events.each do |e|
      src = e["source_id"]
      case e["type"]
      when "attack", "cast"
        dmg = e["damage"].to_i
        if dmg.positive? && src
          metrics[src]["damage_dealt"] += dmg
          last_damager[e["target_id"]] = src
        end
        heal = e["healing"].to_i
        # Count only healing/shielding directed at an ally (not self-drain like
        # Vampiric Drain, which sets source_health_after and targets an enemy).
        if heal.positive? && src && e["source_health_after"].nil?
          tgt = e["target_id"]
          metrics[src]["healing_done"] += heal if tgt && tgt != src && @team_of.call(tgt) == @team_of.call(src)
        end
      when "status"
        # DoT ticks can land the killing blow; credit the effect's applier.
        last_damager[e["unit_id"]] = e["source_id"] if e["source_id"]
      when "death"
        killer = last_damager[e["unit_id"]]
        if killer && @team_of.call(killer) && @team_of.call(killer) != @team_of.call(e["unit_id"])
          metrics[killer]["kills"] += 1
        end
      end
    end

    metrics
  end
end
