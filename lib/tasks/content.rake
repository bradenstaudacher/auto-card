require "yaml"
require "json"

# `rake content:browser` — generates a self-contained static HTML page that
# shows every piece of game content (champions, abilities, cards, monsters,
# rounds) read straight from config/game/*.yml. Pure Ruby, no database — mirrors
# `combat:sample`. Output lands at public/content.html so it can be opened
# directly (file://) or served by Rails at /content.html. Regenerate after
# editing any YAML to refresh the view.
namespace :content do
  desc "Generate a static HTML browser of all game content -> public/content.html"
  task :browser do
    game_dir = File.expand_path("../../config/game", __dir__)
    load_yaml = ->(name) { YAML.load_file(File.join(game_dir, name)) }

    data = {
      generated_at: Time.now.strftime("%Y-%m-%d %H:%M"),
      champions: load_yaml.call("champions.yml")["champions"],
      abilities: load_yaml.call("abilities.yml")["abilities"],
      cards: load_yaml.call("cards.yml")["cards"],
      monsters: load_yaml.call("monsters.yml")["monsters"],
      rounds: load_yaml.call("rounds.yml")["single_player"],
    }

    out_path = File.expand_path("../../public/content.html", __dir__)
    template = File.read(File.expand_path("content_browser.html.erb", __dir__))
    # Embed the data as JSON; escape </ so it can't break out of the <script>.
    json = data.to_json.gsub("</", '<\/')
    html = template.sub("__GAME_DATA__", json)
    File.write(out_path, html)

    counts = {
      champions: data[:champions].size,
      abilities: data[:abilities].size,
      cards: data[:cards].size,
      monsters: data[:monsters].size,
      rounds: data[:rounds].size,
    }
    puts "Wrote #{out_path}"
    puts "  #{counts.map { |k, v| "#{v} #{k}" }.join(', ')}"
    puts "  Open file://#{out_path}  (or /content.html when Rails is running)"
  end
end
