import { useState, useMemo } from 'react'
import { api } from '../api'
import { startChampionDrag, isCardDrag, CARD_DND } from '../dnd'
import Bench from './Bench'
import PlacementGrid from './PlacementGrid'
import Tableau from './Tableau'
import CharacterModal from './CharacterModal'
import BattleStage from './BattleStage'

export default function PreparationScreen({ run, me, onUpdate, onAbandon, replayRound, onReplayComplete }) {
  const battle = replayRound || null
  const isCoop = run.mode === 'two_player_coop'
  const player = me ? run.players.find((p) => p.id === me.player_id) : run.players[0]
  const round = run.current_round_data
  const slots = isCoop ? 2 : (round.player_slots || 1)
  const enemies = round.encounter?.units || []
  const iAmReady = !!player.ready

  // Roster lookup across BOTH players so we can render an ally's locked champions.
  const rosterById = useMemo(() => {
    const m = {}
    run.players.forEach((p) => p.roster.forEach((c) => { m[c.id] = c }))
    return m
  }, [run.players])

  // Seats whose player has locked in this round. Placement_data may be pre-filled
  // from last round's formation (carry-forward), so a seat only counts as "locked"
  // once its player is actually ready.
  const readySeats = useMemo(
    () => new Set(run.players.filter((p) => p.ready).map((p) => p.seat)),
    [run.players]
  )

  // Champions locked onto the board: a ready ally's formation, plus mine once
  // I've locked in (so I see the final formation while waiting).
  const lockedAllies = useMemo(() => {
    const out = []
    Object.entries(round.placement_data || {}).forEach(([seat, list]) => {
      const seatNum = Number(seat)
      if (seatNum === player.seat) { if (!iAmReady) return }
      else if (!readySeats.has(seatNum)) return // ally hasn't locked in yet
      list.forEach((pl) => out.push({ pcId: pl.player_character_id, x: pl.x, y: pl.y }))
    })
    return out
  }, [round.placement_data, player.seat, iAmReady, readySeats])

  // Start the board with my carried-forward formation (from placement_data),
  // editable — so I tweak rather than redeploy from scratch. Runs once per mount;
  // PreparationScreen remounts each round, so it re-seeds from the new round.
  const [placements, setPlacements] = useState(() => {
    const mine = (round.placement_data || {})[String(player.seat)] || []
    return mine.reduce((acc, pl) => { acc[pl.player_character_id] = { x: pl.x, y: pl.y }; return acc }, {})
  }) // pcId -> {x,y}
  const [modalPcId, setModalPcId] = useState(null)
  const [error, setError] = useState(null)
  const [submitting, setSubmitting] = useState(false)

  const placedIds = new Set(Object.keys(placements).map(Number))
  const placedCount = placedIds.size

  function onDragStart(e, pcId) { startChampionDrag(e, pcId) }

  function onDrop(e, x, y) {
    if (isCardDrag(e)) return // card drops are handled by champion tokens, not tiles
    e.preventDefault()
    const pcId = Number(e.dataTransfer.getData('text/plain'))
    if (!pcId) return
    setError(null)
    if (lockedAllies.some((a) => a.x === x && a.y === y)) {
      setError("Your ally already claimed that tile.")
      return
    }
    setPlacements((prev) => {
      const occupant = Object.entries(prev).find(([id, p]) => p.x === x && p.y === y && Number(id) !== pcId)
      const alreadyPlaced = pcId in prev
      if (occupant) {
        if (!alreadyPlaced) {
          setError('That tile is taken — drop on an empty tile or swap two placed champions.')
          return prev
        }
        const [otherId] = occupant
        const from = prev[pcId]
        return { ...prev, [pcId]: { x, y }, [otherId]: from }
      }
      if (!alreadyPlaced && Object.keys(prev).length >= slots) {
        setError(`You can only deploy ${slots} champion${slots > 1 ? 's' : ''} this round.`)
        return prev
      }
      return { ...prev, [pcId]: { x, y } }
    })
  }

  function unplace(pcId) {
    setPlacements((prev) => { const n = { ...prev }; delete n[pcId]; return n })
  }

  // Drag a tableau card onto a champion (bench or grid): XP cards are consumed
  // to grant experience; everything else is equipped.
  async function onChampionCardDrop(e, pcId) {
    if (!isCardDrag(e)) return
    e.preventDefault()
    const cardId = Number(e.dataTransfer.getData(CARD_DND))
    if (!cardId) return
    setError(null)
    const card = player.tableau.find((c) => c.id === cardId)
    try {
      const updated = card?.category === 'xp'
        ? await api.feedCard(run.id, cardId, pcId)
        : await api.assignCard(run.id, cardId, pcId)
      onUpdate(updated)
    } catch (err) {
      setError((err.errors || [err.message]).join(' · '))
    }
  }

  async function unequip(playerCardId) {
    setError(null)
    try { onUpdate(await api.unassignCard(run.id, playerCardId)) }
    catch (err) { setError((err.errors || [err.message]).join(' · ')) }
  }

  async function reorderAbilities(pcId, order) {
    try { onUpdate(await api.reorderAbilities(run.id, pcId, order)) }
    catch (err) { setError((err.errors || [err.message]).join(' · ')) }
  }

  async function discard(playerCardId) {
    setError(null)
    try { onUpdate(await api.discardCard(run.id, playerCardId)) }
    catch (err) { setError((err.errors || [err.message]).join(' · ')) }
  }

  async function reorderCards(orderedIds) {
    setError(null)
    try { onUpdate(await api.reorderCards(run.id, player.id, orderedIds)) }
    catch (err) { setError((err.errors || [err.message]).join(' · ')) }
  }

  async function lockIn() {
    setSubmitting(true)
    setError(null)
    try {
      const body = Object.entries(placements).map(([id, p]) => ({
        player_character_id: Number(id), x: p.x, y: p.y,
      }))
      onUpdate(await api.submitPlacement(run.id, player.id, body))
    } catch (e) {
      setError((e.errors || [e.message]).join(' · '))
      setSubmitting(false)
    }
  }

  const modalChampion = modalPcId != null ? rosterById[modalPcId] : null

  return (
    <div className={`screen game-screen${battle ? ' battle-mode' : ''}`}>
      <header className="topbar">
        <span className="round-pill">Round {run.current_round}/{run.max_rounds}{round.boss ? ' · BOSS' : ''}</span>
        <span className="deploy-count">{battle ? 'Battle' : `Deployed ${iAmReady ? slots : placedCount}/${slots}`}</span>
        {isCoop && <span className="coop-tag">CO-OP · Seat {player.seat}</span>}
        <button className="btn btn-ghost" onClick={onAbandon}>{isCoop ? 'Leave' : 'Abandon Run'}</button>
      </header>

      <div className="game-layout">
        <Bench
          roster={player.roster}
          placedIds={placedIds}
          onDragStart={onDragStart}
          onInspect={setModalPcId}
          onCardDrop={onChampionCardDrop}
        />

        <main className="stage">
          {battle ? (
            <BattleStage run={run} round={battle} onComplete={onReplayComplete} />
          ) : (
            <>
              <PlacementGrid
                enemies={enemies}
                placements={iAmReady ? {} : placements}
                lockedAllies={lockedAllies}
                rosterById={rosterById}
                onDrop={onDrop}
                onDragStartPlaced={onDragStart}
                onInspectPlaced={setModalPcId}
                onUnplace={unplace}
                onCardDrop={onChampionCardDrop}
              />
              {error && <p className="error-text">{error}</p>}
              {iAmReady ? (
                <p className="waiting-banner"><span className="pulse-dot" /> Locked in — waiting for your ally…</p>
              ) : (
                <button className="btn btn-primary btn-lg lockin" disabled={placedCount === 0 || submitting} onClick={lockIn}>
                  {submitting ? 'Resolving…' : 'Lock In & Fight'}
                </button>
              )}
            </>
          )}
        </main>
      </div>

      <Tableau cards={player.tableau} rosterById={rosterById} onDiscard={discard} onReorder={reorderCards} />

      {modalChampion && (
        <CharacterModal
          champion={modalChampion}
          placed={placedIds.has(modalPcId)}
          onClose={() => setModalPcId(null)}
          onUnplace={() => unplace(modalPcId)}
          onUnequip={unequip}
          onCardDrop={(e) => onChampionCardDrop(e, modalPcId)}
          onReorder={(order) => reorderAbilities(modalPcId, order)}
        />
      )}
    </div>
  )
}
