class RewardOffer < ApplicationRecord
  STATUSES = %w[pending selected].freeze

  belongs_to :player
  belongs_to :battle_round
  belongs_to :selected_card_template, class_name: "CardTemplate",
             foreign_key: :selected_card_template_id, optional: true

  validates :status, inclusion: { in: STATUSES }

  def selected?
    status == "selected"
  end

  # Whether a given card_template id was one of the offered choices.
  def offered?(card_template_id)
    choices.any? { |c| c["card_template_id"] == card_template_id }
  end
end
