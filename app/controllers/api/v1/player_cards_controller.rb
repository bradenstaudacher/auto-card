module Api
  module V1
    class PlayerCardsController < BaseController
      # POST /api/v1/runs/:run_id/player_cards/:id/assign  { player_character_id }
      def assign
        session = load_session
        return preparation_error unless session.status == "preparation"

        card = scoped_cards(session).find(params[:id])
        character = scoped_characters(session).find(params.require(:player_character_id))
        result = CardAssignment.assign(card, character)

        result.ok? ? render_run(session.reload) : render_errors(result.errors)
      end

      # POST /api/v1/runs/:run_id/player_cards/:id/unassign
      def unassign
        session = load_session
        return preparation_error unless session.status == "preparation"

        card = scoped_cards(session).find(params[:id])
        CardAssignment.unassign(card)
        render_run(session.reload)
      end

      # POST /api/v1/runs/:run_id/player_cards/:id/feed  { player_character_id }
      # Consumes an XP card, granting its XP to the target champion.
      def feed
        session = load_session
        return preparation_error unless %w[preparation reward].include?(session.status)

        card = scoped_cards(session).find(params[:id])
        character = scoped_characters(session).find(params.require(:player_character_id))
        result = ExperienceFeed.consume(card, character)

        result.ok? ? render_run(session.reload) : render_errors(result.errors)
      end

      # DELETE /api/v1/runs/:run_id/player_cards/:id
      # Permanently discards a card from the tableau (unequipping it first).
      def destroy
        session = load_session
        return preparation_error unless session.status == "preparation"

        card = scoped_cards(session).find(params[:id])
        CardAssignment.unassign(card) if card.assigned?
        card.destroy!
        render_run(session.reload)
      end

      # PATCH /api/v1/runs/:run_id/player_cards/reorder
      #   { player_id, ordered_ids: [cardId, ...] }
      # Persists the tableau's display order. Only the listed cards are touched,
      # and only ones belonging to the given player in this session.
      def reorder
        session = load_session
        return preparation_error unless session.status == "preparation"

        player = session.players.find(params.require(:player_id))
        ordered_ids = Array(params.require(:ordered_ids)).map(&:to_i)
        cards = player.player_cards.where(id: ordered_ids).index_by(&:id)

        ActiveRecord::Base.transaction do
          ordered_ids.each_with_index do |card_id, index|
            cards[card_id]&.update!(position: index)
          end
        end
        render_run(session.reload)
      end

      private

      def load_session
        GameSession.find(params[:run_id])
      end

      def scoped_cards(session)
        PlayerCard.joins(:player).where(players: { game_session_id: session.id })
      end

      def scoped_characters(session)
        PlayerCharacter.joins(:player).where(players: { game_session_id: session.id })
      end

      def render_errors(errors)
        render json: { errors: errors }, status: :unprocessable_entity
      end

      def preparation_error
        render json: { errors: ["loadouts can only be changed during preparation"] },
               status: :unprocessable_entity
      end
    end
  end
end
