# Backing store for the content brainstorm board (public/board.html).
#
# Drafts are proposed/edited game cards awaiting triage. They live in a plain
# JSON file in the repo (config/game/content_drafts.json) so they are
# git-diffable and reviewable — deliberately NOT in the game DB, since this is a
# design tool, not runtime state. The board drives everything through the
# Api::V1::DraftsController which delegates here.
#
# STATUSES: proposed -> edits_needed -> accepted -> rejected (free movement).
# "Promoting" accepted drafts appends them to config/game/cards.yml as real,
# shippable content. We APPEND rather than rewrite so the file's hand-written
# comments and ordering survive.
class ContentDraftStore
  PATH = Rails.root.join("config", "game", "content_drafts.json")
  CARDS_PATH = Rails.root.join("config", "game", "cards.yml")
  STATUSES = %w[proposed edits_needed accepted rejected].freeze
  CATEGORIES = %w[ability weapon equipment passive modifier].freeze

  class << self
    def all
      read.fetch("drafts")
    end

    # Live game content, read-only, so the board can show a "Live (core)"
    # reference column and warn on key collisions.
    def core
      {
        cards: GameContent.cards,
        abilities: GameContent.abilities,
        champions: GameContent.champions,
        monsters: GameContent.monsters,
      }
    end

    def create(attrs)
      mutate do |drafts|
        draft = normalize(attrs).merge(
          "id" => "draft_#{SecureRandom.hex(4)}",
          "status" => STATUSES.include?(attrs["status"]) ? attrs["status"] : "proposed",
          "notes" => attrs["notes"].to_s,
          "origin" => attrs["origin"].presence || "manual"
        )
        drafts << draft
        draft
      end
    end

    def update(id, attrs)
      mutate do |drafts|
        draft = drafts.find { |d| d["id"] == id } or raise ActiveRecord::RecordNotFound, "draft #{id}"
        # Only touch keys that were actually sent; status is validated.
        attrs.slice(*(%w[name category type_affinity rarity slot_type tier key upgrades_to description rules status notes])).each do |k, v|
          next if k == "status" && !STATUSES.include?(v)
          draft[k] = v
        end
        draft
      end
    end

    def destroy(id)
      mutate { |drafts| drafts.reject! { |d| d["id"] == id } }
      true
    end

    # Append every accepted, not-yet-promoted draft to cards.yml and mark it
    # promoted. Returns the list of promoted drafts. Idempotent: re-running
    # promotes nothing new.
    def promote!
      promoted = []
      mutate do |drafts|
        ready = drafts.select { |d| d["status"] == "accepted" && !d["promoted"] }
        next promoted if ready.empty?

        yaml_blocks = ready.map { |d| card_yaml_block(d) }
        File.open(CARDS_PATH, "a") do |f|
          f.puts
          f.puts "  # --- Promoted from the content board on #{Time.now.strftime('%Y-%m-%d')} ---"
          yaml_blocks.each { |b| f.puts(b) }
        end
        ready.each { |d| d["promoted"] = true }
        promoted = ready
      end
      promoted
    end

    private

    def read
      return { "drafts" => [] } unless File.exist?(PATH)

      JSON.parse(File.read(PATH))
    rescue JSON::ParserError
      { "drafts" => [] }
    end

    def mutate
      PATH.dirname.mkpath
      File.open(PATH, File::RDWR | File::CREAT, 0o644) do |f|
        f.flock(File::LOCK_EX)
        content = f.read
        data = content.empty? ? { "drafts" => [] } : (JSON.parse(content) rescue { "drafts" => [] })
        result = yield(data["drafts"])
        f.rewind
        f.truncate(0)
        f.write(JSON.pretty_generate(data))
        result
      end
    end

    def normalize(attrs)
      {
        "name" => attrs["name"].to_s,
        "category" => CATEGORIES.include?(attrs["category"]) ? attrs["category"] : "ability",
        "type_affinity" => attrs["type_affinity"].presence,
        "rarity" => attrs["rarity"].presence || "common",
        "slot_type" => attrs["slot_type"].presence,
        "tier" => attrs["tier"],
        "key" => attrs["key"].presence,
        "upgrades_to" => attrs["upgrades_to"].presence,
        "description" => attrs["description"].to_s,
        "rules" => attrs["rules"].is_a?(Hash) ? attrs["rules"] : {},
      }.compact
    end

    # Renders one draft as a cards.yml entry. Derives a snake_case key from the
    # name if the draft has none. Uses YAML.dump for the value blocks so nested
    # rules serialize correctly, re-indented under the list item.
    def card_yaml_block(draft)
      key = draft["key"].presence || "card_#{draft['name'].to_s.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/^_|_$/, '')}"
      entry = {
        "key" => key,
        "name" => draft["name"],
        "category" => draft["category"],
        "type_affinity" => draft["type_affinity"],
        "rarity" => draft["rarity"],
        "slot_type" => draft["slot_type"] || draft["category"],
        "description" => draft["description"],
        "valid_types" => draft["valid_types"] || [],
        "valid_subclasses" => draft["valid_subclasses"] || [],
      }
      entry["tier"] = draft["tier"] if draft["tier"]
      entry["upgrades_to"] = draft["upgrades_to"] if draft["upgrades_to"].present?
      entry["rules"] = draft["rules"] if draft["rules"].is_a?(Hash) && draft["rules"].any?

      # YAML.dump emits "---\nkey: ...\n"; strip the doc marker and indent each
      # line by 2 (list) + turn the first line into a "- " bullet.
      body = YAML.dump(entry).sub(/\A---\n/, "").chomp
      lines = body.lines.map { |l| "    #{l.chomp}" }
      lines[0] = "  - #{lines[0].strip}"
      lines.join("\n")
    end
  end
end
