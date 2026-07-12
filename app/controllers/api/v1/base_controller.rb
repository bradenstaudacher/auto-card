module Api
  module V1
    class BaseController < ActionController::API
      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActionController::ParameterMissing, with: :bad_request

      private

      def render_run(session, status: :ok)
        render json: RunSerializer.call(session), status: status
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
