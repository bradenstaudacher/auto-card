require "yaml"

# `rake combat:sample` — runs a sample PvE encounter through the deterministic
# engine and prints a human-readable battle log. Lets us SEE combat working
# before any UI exists. Pure Ruby: does not require the database.
namespace :combat do
  desc "Simulate a sample encounter and print a readable battle log"
  task :sample do
    require_relative "../combat"

    game_dir = File.expand_path("../../config/game", __dir__)
    champions = YAML.load_file(File.join(game_dir, "champions.yml"))["champions"]
    monsters  = YAML.load_file(File.join(game_dir, "monsters.yml"))["monsters"]

    def find(list, key) = list.find { |c| c["key"] == key }

    def to_unit(tpl, id:, team:, x:, y:, abilities: [])
      { id: id, team: team, name: tpl["name"], type: tpl["type"],
        subclass: tpl["subclass"], position: { x: x, y: y },
        stats: tpl["base_stats"].transform_keys(&:to_sym), abilities: abilities }
    end

    reaper = find(champions, "hollow_reaper")
    warrior = find(champions, "ember_vanguard")
    guard = find(monsters, "oathbound_guard")
    hound = find(monsters, "ash_hound")
    imp   = find(monsters, "lesser_imp")

    units = [
      to_unit(reaper, id: "p_reaper", team: "allies", x: 0, y: 1,
              abilities: [{ name: "Vampiric Drain", priority: 1 }]),
      to_unit(warrior, id: "p_warrior", team: "allies", x: 0, y: 3,
              abilities: [{ name: "Cleave", priority: 1 }]),
      to_unit(guard, id: "m_guard", team: "monsters", x: 7, y: 2),
      to_unit(hound, id: "m_hound", team: "monsters", x: 7, y: 1),
      to_unit(imp,   id: "m_imp",   team: "monsters", x: 7, y: 3)
    ]

    input = { seed: "sample-001", grid: { rows: 6, columns: 8 }, units: units }
    out = Combat::Simulator.new(input).run

    puts "=" * 64
    puts "SAMPLE ENCOUNTER  (seed=#{input[:seed]})"
    puts "  Allies : #{units.select { |u| u[:team] == 'allies' }.map { |u| u[:name] }.join(', ')}"
    puts "  Monsters: #{units.select { |u| u[:team] == 'monsters' }.map { |u| u[:name] }.join(', ')}"
    puts "=" * 64
    names = units.to_h { |u| [u[:id], u[:name]] }

    out[:events].each do |e|
      line =
        case e[:type]
        when "move"
          "  move   #{names[e[:unit_id]].ljust(16)} #{e[:from][:x]},#{e[:from][:y]} -> #{e[:to][:x]},#{e[:to][:y]}"
        when "attack"
          "  attack #{names[e[:source_id]].ljust(16)} -> #{names[e[:target_id]]}  (#{e[:damage]} dmg, target hp #{e[:target_health_after]})"
        when "cast"
          heal = e[:healing] ? ", heal #{e[:healing]}" : ""
          "  CAST   #{names[e[:source_id]].ljust(16)} #{e[:ability_name]} -> #{names[e[:target_id]]}  (#{e[:damage]} dmg#{heal})"
        when "death"
          "  DEATH  #{names[e[:unit_id]]} falls"
        end
      puts "  [t#{e[:tick].to_s.rjust(3)}]#{line}"
    end

    puts "=" * 64
    puts "WINNER: #{out[:winner]}   (#{out[:duration_ticks]} ticks / #{out[:duration_ticks] * out[:tick_ms] / 1000.0}s)"
    out[:final_units].each do |u|
      status = u[:alive] ? "#{u[:current_health]}/#{u[:max_health]} hp" : "DEAD"
      puts "  #{u[:name].ljust(18)} [#{u[:team]}]  #{status}"
    end
    puts "=" * 64
  end
end
