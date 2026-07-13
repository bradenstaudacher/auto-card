module Api
  module V1
    class BaseController < ActionController::API
      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActionController::ParameterMissing, with: :bad_request

      private

      def render_run(session, status: :ok)
        heal_card_combines(session)
        render json: RunSerializer.call(session), status: status
      end

      # Combining normally fires the instant a reward is picked, but that makes it
      # a one-shot: any trio that forms outside that path (legacy data, an
      # interrupted post-reward combine, a future card grant) would otherwise sit
      # in the tableau forever showing "3/3 → upgrades" without fusing. Re-running
      # the idempotent combiner whenever the player views their tableau makes it
      # self-healing. Only during phases where the tableau is editable.
      def heal_card_combines(session)
        return unless %w[preparation reward].include?(session.status)

        session.players.each { |player| CardCombiner.combine!(player) }
      rescue StandardError => e
        Rails.logger.warn("heal_card_combines failed: #{e.message}")
      end

      def not_found(error)
        render json: { error: error.message }, status: :not_found
      end

      def bad_request(error)
        render json: { error: error.message }, status: :bad_request
      end
    end
  end
end
