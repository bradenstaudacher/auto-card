module Api
  module V1
    class CoopController < BaseController
      # POST /api/v1/coop  { handle } -> creates a lobby (seat 1)
      def create
        user = User.create!(handle: params[:handle].presence || "Host-#{SecureRandom.hex(3)}")
        session = RunOrchestrator.start_coop(user: user)
        render json: coop_payload(session, session.players.first), status: :created
      end

      # POST /api/v1/coop/join  { room_code, handle } -> joins as seat 2
      def join
        user = User.create!(handle: params[:handle].presence || "Guest-#{SecureRandom.hex(3)}")
        result = RunOrchestrator.join_coop(room_code: params.require(:room_code), user: user)

        if result.ok?
          session = result.data
          CoopBroadcaster.broadcast(session) # notify the host that P2 joined
          render json: coop_payload(session, session.players.find_by(seat: 2))
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      private

      # Co-op clients need to know which player is theirs.
      def coop_payload(session, player)
        RunSerializer.call(session).merge(me: { player_id: player.id, seat: player.seat })
      end
    end
  end
end
