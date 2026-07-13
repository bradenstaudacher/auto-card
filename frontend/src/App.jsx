import { useState, useEffect } from 'react'
import { api } from './api'
import { subscribeToSession } from './cable'
import StartScreen from './components/StartScreen'
import LobbyScreen from './components/LobbyScreen'
import PreparationScreen from './components/PreparationScreen'
import RewardScreen from './components/RewardScreen'
import CompletedScreen from './components/CompletedScreen'
import './styles.css'

const RUN_KEY = 'auto_card_run_id'
const ME_KEY = 'auto_card_me'

export default function App() {
  const [run, setRun] = useState(null)
  const [me, setMe] = useState(null) // { player_id, seat } in co-op; null in single-player
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [watched, setWatched] = useState(null)
  const [toast, setToast] = useState(null)

  useEffect(() => {
    const saved = localStorage.getItem(RUN_KEY)
    const savedMe = localStorage.getItem(ME_KEY)
    if (savedMe) { try { setMe(JSON.parse(savedMe)) } catch { /* noop */ } }
    if (!saved) { setLoading(false); return }
    api.getRun(saved).then(setRun).catch(() => {
      localStorage.removeItem(RUN_KEY); localStorage.removeItem(ME_KEY)
    }).finally(() => setLoading(false))
  }, [])

  // Live sync for co-op: subscribe to the session channel; incoming state wins.
  useEffect(() => {
    if (!run || run.mode !== 'two_player_coop') return
    const unsub = subscribeToSession(run.id, (state) => {
      setWatched((w) => (state.status === 'reward' ? (w?.startsWith?.('seen-') ? w : null) : w))
      setRun((prev) => ({ ...state, mode: state.mode }))
    })
    return unsub
  }, [run?.id, run?.mode])

  useEffect(() => {
    if (!toast) return
    const t = setTimeout(() => setToast(null), 2600)
    return () => clearTimeout(t)
  }, [toast])

  function persist(r, meVal) {
    localStorage.setItem(RUN_KEY, r.id)
    if (meVal) { localStorage.setItem(ME_KEY, JSON.stringify(meVal)); setMe(meVal) }
  }

  async function startRun(handle) {
    setError(null)
    try { const r = await api.startRun(handle); localStorage.removeItem(ME_KEY); setMe(null); persist(r); setWatched(null); setRun(r) }
    catch (e) { setError(e.message) }
  }
  async function createCoop(handle) {
    setError(null)
    try { const r = await api.createCoop(handle); persist(r, r.me); setWatched(null); setRun(r) }
    catch (e) { setError(e.message) }
  }
  async function joinCoop(code, handle) {
    setError(null)
    try { const r = await api.joinCoop(code, handle); persist(r, r.me); setWatched(null); setRun(r) }
    catch (e) { setError((e.errors || [e.message]).join(' · ')) }
  }

  function abandon() {
    localStorage.removeItem(RUN_KEY); localStorage.removeItem(ME_KEY)
    setRun(null); setMe(null); setWatched(null)
  }

  function update(r) {
    if (r.status === 'reward') setWatched(null)
    if (r.combined && r.combined.length) setToast(r.combined)
    setRun(r)
  }

  function screen() {
    if (loading) return <div className="app-loading">Loading…</div>
    if (!run) return <StartScreen onStart={startRun} onCreateCoop={createCoop} onJoinCoop={joinCoop} error={error} />
    if (run.status === 'lobby') return <LobbyScreen run={run} onAbandon={abandon} />
    if (run.status === 'completed') return <CompletedScreen run={run} onRestart={abandon} />

    const round = run.current_round_data
    const seenTag = round ? `seen-${round.round_number}` : null

    if (run.status === 'reward' && round?.status === 'resolved' && watched !== seenTag) {
      return (
        <PreparationScreen
          run={run} me={me} onUpdate={update} onAbandon={abandon}
          replayRound={round} onReplayComplete={() => setWatched(seenTag)}
        />
      )
    }
    if (run.status === 'reward') {
      return <RewardScreen run={run} me={me} onUpdate={update} onWatchAgain={() => setWatched(null)} />
    }
    return <PreparationScreen run={run} me={me} onUpdate={update} onAbandon={abandon} />
  }

  return (
    <>
      {screen()}
      {toast && (
        <div className="combine-toast">
          <span className="combine-spark">✦</span>
          Combined into <strong>{toast.join(', ')}</strong>!
        </div>
      )}
    </>
  )
}
