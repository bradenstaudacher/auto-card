export default function CompletedScreen({ run, onRestart }) {
  const lastRound = run.current_round_data
  const won = lastRound?.result?.winner === 'allies'
  return (
    <div className="screen center-screen">
      <div className="title-card">
        <h1 className="game-title">{won ? 'RUN COMPLETE' : 'RUN OVER'}</h1>
        <p className="tagline">
          You reached round {run.current_round} of {run.max_rounds}.
          {won ? ' The final boss has fallen.' : ' Better luck next run.'}
        </p>
        <button className="btn btn-primary btn-lg" onClick={onRestart}>
          New Run
        </button>
      </div>
    </div>
  )
}
