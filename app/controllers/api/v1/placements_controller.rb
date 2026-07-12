module Api
  module V1
    class PlacementsController < BaseController
      # POST /api/v1/runs/:run_id/placements
      # Body: { player_id, placements: [{ player_character_id, x, y }, ...] }
      # Validates + stores placement; resolves the battle when all seats ready.
      def create
        session = GameSession.find(params[:run_id])
        player = session.players.find(placement_params[:player_id])

        result = RunOrchestrator.new(session).submit_placement(
          player: player,
          placements: placement_params[:placements].map(&:to_h)
        )

        if result.ok?
          session.reload
          CoopBroadcaster.broadcast(session)
          render_run(session)
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      private

      def placement_params
        params.permit(:player_id, placements: %i[player_character_id x y])
      end
    end
  end
end
