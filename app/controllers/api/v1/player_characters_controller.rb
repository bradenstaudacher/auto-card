module Api
  module V1
    class PlayerCharactersController < BaseController
      # PATCH /api/v1/runs/:run_id/player_characters/:id/ability_order  { order: [names] }
      # Reorders cast priority. Only names the champion actually has are kept.
      def ability_order
        session = GameSession.find(params[:run_id])
        return preparation_error unless session.status == "preparation"

        character = PlayerCharacter.joins(:player)
                                   .where(players: { game_session_id: session.id })
                                   .find(params[:id])

        requested = Array(params.require(:order))
        available = available_abilities(character)
        ordered = requested.select { |n| available.include?(n) }
        # Append any available abilities the client omitted so none are lost.
        ordered += (available - ordered)

        character.update!(ability_priority: ordered)
        render_run(session.reload)
      end

      private

      def available_abilities(character)
        Array(character.champion_template.default_abilities) +
          character.player_cards.includes(:card_template)
                   .select { |c| c.category == "ability" }.map(&:ability_name)
      end

      def preparation_error
        render json: { errors: ["loadouts can only be changed during preparation"] },
               status: :unprocessable_entity
      end
    end
  end
end
