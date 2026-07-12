// Thin client over the Rails JSON API. All calls go through the Vite proxy.
const BASE = '/api/v1'

async function request(path, { method = 'GET', body } = {}) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) {
    const err = new Error(data.error || (data.errors || []).join(', ') || `HTTP ${res.status}`)
    err.status = res.status
    err.errors = data.errors
    throw err
  }
  return data
}

export const api = {
  startRun: (handle) => request('/runs', { method: 'POST', body: { handle } }),
  createCoop: (handle) => request('/coop', { method: 'POST', body: { handle } }),
  joinCoop: (roomCode, handle) =>
    request('/coop/join', { method: 'POST', body: { room_code: roomCode, handle } }),
  getRun: (id) => request(`/runs/${id}`),
  submitPlacement: (runId, playerId, placements) =>
    request(`/runs/${runId}/placements`, {
      method: 'POST',
      body: { player_id: playerId, placements },
    }),
  selectReward: (runId, offerId, cardTemplateId) =>
    request(`/runs/${runId}/rewards/${offerId}/select`, {
      method: 'POST',
      body: { card_template_id: cardTemplateId },
    }),
  assignCard: (runId, playerCardId, playerCharacterId) =>
    request(`/runs/${runId}/player_cards/${playerCardId}/assign`, {
      method: 'POST',
      body: { player_character_id: playerCharacterId },
    }),
  unassignCard: (runId, playerCardId) =>
    request(`/runs/${runId}/player_cards/${playerCardId}/unassign`, { method: 'POST' }),
  discardCard: (runId, playerCardId) =>
    request(`/runs/${runId}/player_cards/${playerCardId}`, { method: 'DELETE' }),
  reorderAbilities: (runId, playerCharacterId, order) =>
    request(`/runs/${runId}/player_characters/${playerCharacterId}/ability_order`, {
      method: 'PATCH',
      body: { order },
    }),
}
