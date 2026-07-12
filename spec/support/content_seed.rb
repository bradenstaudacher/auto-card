# Reference content (champion + card templates) is committed once before the
# suite so it survives the per-example transaction rollback. Mirrors db/seeds.rb.
RSpec.configure do |config|
  config.before(:suite) do
    GameContent.champions.each do |c|
      ChampionTemplate.find_or_initialize_by(key: c["key"]).update!(
        name: c["name"], type_key: c["type"], subclass: c["subclass"],
        color: c["color"], role: c["role"], base_stats: c["base_stats"],
        slot_config: c["slot_config"], default_abilities: c["default_abilities"] || []
      )
    end
    GameContent.cards.each do |c|
      CardTemplate.find_or_initialize_by(key: c["key"]).update!(
        name: c["name"], category: c["category"], type_affinity: c["type_affinity"],
        rarity: c["rarity"], slot_type: c["slot_type"], description: c["description"],
        valid_types: c["valid_types"] || [], valid_subclasses: c["valid_subclasses"] || [],
        rules: c["rules"] || {}, tier: c["tier"] || 1, upgrades_to_key: c["upgrades_to"]
      )
    end
  end
end
