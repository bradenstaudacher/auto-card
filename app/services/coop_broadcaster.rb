# Pushes the current run state to both co-op clients over Action Cable. No-op
# for single-player. Call after any server-side state change in a co-op run.
module CoopBroadcaster
  module_function

  def broadcast(session)
    return unless session.coop?
    GameSessionChannel.broadcast_to(session, RunSerializer.call(session))
  end
end
