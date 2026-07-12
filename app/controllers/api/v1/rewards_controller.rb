module Api
  module V1
    class RewardsController < BaseController
      # POST /api/v1/runs/:run_id/rewards/:id/select
      # Body: { card_template_id }
      # Grants the chosen card; advances the run when all offers are resolved.
      def select
        session = GameSession.find(params[:run_id])
        offer = RewardOffer.joins(:battle_round)
                           .where(battle_rounds: { game_session_id: session.id })
                           .find(params[:id])

        result = RunOrchestrator.new(session).select_reward(
          reward_offer: offer,
          card_template_id: params.require(:card_template_id)
        )

        if result.ok?
          session.reload
          CoopBroadcaster.broadcast(session)
          body = RunSerializer.call(session).merge(combined: result.data[:combined] || [])
          render json: body
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end
    end
  end
end
