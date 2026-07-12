# Real-time channel for a co-op run. Both players subscribe with the session id
# and receive the full serialized run state whenever it changes, keeping their
# boards in sync. Server-authoritative: clients render what they receive.
class GameSessionChannel < ApplicationCable::Channel
  def subscribed
    session = GameSession.find_by(id: params[:session_id])
    return reject unless session

    stream_for session
  end
end
