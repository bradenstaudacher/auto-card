// Minimal Action Cable client over a native WebSocket (avoids the npm
// dependency). Implements just the subscribe/message handshake we need.
export function subscribeToSession(sessionId, onData) {
  const proto = location.protocol === 'https:' ? 'wss' : 'ws'
  const ws = new WebSocket(`${proto}://${location.host}/cable`)
  const identifier = JSON.stringify({ channel: 'GameSessionChannel', session_id: sessionId })
  let closed = false

  ws.onopen = () => {} // wait for the server "welcome" before subscribing
  ws.onmessage = (evt) => {
    let msg
    try { msg = JSON.parse(evt.data) } catch { return }
    if (msg.type === 'welcome') {
      ws.send(JSON.stringify({ command: 'subscribe', identifier }))
    } else if (msg.type === 'ping' || msg.type === 'confirm_subscription' || msg.type === 'reject_subscription') {
      // control frames — ignore (ping keeps the socket alive)
    } else if (msg.message) {
      onData(msg.message)
    }
  }
  ws.onclose = () => {}

  return () => { closed = true; try { ws.close() } catch { /* noop */ } }
}
