# Auto-combines duplicate upgrade cards: any three identical cards (a template
# with an upgrade path) fuse into one card of the next tier. Cascades — three
# tier-2s combine into a tier-3 — until no more merges are possible. Copies count
# whether equipped or not; an equipped copy that gets consumed is unequipped
# first (cleaning up ability priority). The produced card lands in the tableau.
# Returns the list of upgrade names produced (for UI messaging).
class CardCombiner
  THRESHOLD = 3

  def self.combine!(player)
    new(player).combine!
  end

  def initialize(player)
    @player = player
  end

  def combine!
    produced = []
    loop do
      merge = next_merge
      break unless merge

      template, cards = merge
      ApplicationRecord.transaction do
        consumed = cards.first(THRESHOLD)
        # Land the upgraded card where the trio sat so the tableau doesn't reshuffle.
        slot = consumed.map(&:position).min
        consumed.each do |card|
          CardAssignment.unassign(card) if card.assigned?
          card.destroy!
        end
        upgraded = @player.player_cards.create!(card_template: template.upgrade_template, position: slot)
        produced << upgraded.card_template.name
      end
    end
    produced
  end

  private

  # First template with >= 3 total copies (equipped or not) that can upgrade.
  def next_merge
    grouped = @player.player_cards.includes(:card_template).group_by(&:card_template_id)

    grouped.each do |_template_id, cards|
      next if cards.size < THRESHOLD
      template = cards.first.card_template
      next unless template.upgrade_template
      return [template, cards]
    end
    nil
  end
end
