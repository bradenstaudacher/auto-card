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

      # POST /api/v1/runs/:id/select_champions  { champion_keys: [key, key, key] }
      def select_champions
        session = find_session
        player = session.players.first
        result = RunOrchestrator.new(session).select_champions(
          player: player, champion_keys: params[:champion_keys]
        )
        if result.ok?
          render_run(session.reload, status: :ok)
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      private

      def find_session
        GameSession.find(params[:id])
      end
    end
  end
end
