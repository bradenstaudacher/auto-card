// Shown to the host while waiting for a second player. Live-updates via Action
// Cable — when P2 joins, the run flips to preparation and App routes onward.
export default function LobbyScreen({ run, onAbandon }) {
  return (
    <div className="screen center-screen">
      <div className="title-card">
        <h1 className="game-title">CO-OP LOBBY</h1>
        <p className="tagline">Share this code with a friend to join your run</p>
        <div className="room-code-display">{run.room_code}</div>
        <p className="lobby-status">
          <span className="pulse-dot" /> Waiting for player 2…
        </p>
        <button className="btn btn-ghost" onClick={onAbandon}>Cancel</button>
      </div>
    </div>
  )
}
