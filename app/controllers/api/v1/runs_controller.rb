module Api
  module V1
    class RunsController < BaseController
      # POST /api/v1/runs
      # Starts a single-player run. Anonymous by default; an optional handle
      # names the user (accounts stay lightweight for MVP).
      def create
        user = User.create!(handle: params[:handle].presence || "Guest-#{SecureRandom.hex(3)}")
        session = RunOrchestrator.start_single_player(user: user)
        render_run(session, status: :created)
      end

      # GET /api/v1/runs/:id
      def show
        render_run(find_session)
      end

      private

      def find_session
        GameSession.find(params[:id])
      end
    end
  end
end
