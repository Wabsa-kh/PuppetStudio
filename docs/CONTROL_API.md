# Local control API · version 1

Enable it explicitly in Output. Default URL is `ws://127.0.0.1:19532`; the port is configurable. Copy connection details to obtain the session token. Tokens are regenerated each time the server starts and are not saved in projects.

Send a UTF-8 JSON text frame containing `{"token":"COPIED_TOKEN"}` first. Success returns `{"ok":true,"event":"authenticated","version":1}`. Invalid authentication closes the connection. Authentication must complete within five seconds.

Then send one command per text frame:

| Command | Meaning |
|---|---|
| `{"action":"expression","index":1}` | Select expression 2 as the base; clears temporary reactions. |
| `{"action":"costume","index":0}` | Select costume 1 and clear live sprite toggles. |
| `{"action":"mute","enabled":true}` | Mute avatar mouth, not the system microphone. |
| `{"action":"blink"}` | Trigger a blink. |
| `{"action":"clips","enabled":true}` | Start enabled motion clips from time zero. False stops preview. |
| `{"action":"reset"}` | Restore expression 1/default costume, unmute, stop clips. |

Indices are zero-based and must exist. Accepted commands return `{"ok":true,"event":"accepted"}`. Invalid commands return `{"ok":false,"error":"..."}`. Limits: four clients, 4096-byte JSON text frames, 10 commands/sec per connection with a burst of 20. The API does not execute scripts, accept file paths or expose arbitrary app properties.

Example using a browser's standard WebSocket API (the token is a placeholder):

```javascript
const socket = new WebSocket('ws://127.0.0.1:19532');
socket.onopen = () => socket.send(JSON.stringify({token: 'COPIED_TOKEN'}));
socket.onmessage = ({data}) => {
  const message = JSON.parse(data);
  if (message.event === 'authenticated') {
    socket.send(JSON.stringify({action: 'expression', index: 0}));
  }
};
```

Local scripts and configurable WebSocket clients can use this API. This release does not supply a ready-made Stream Deck plugin or match another application's protocol.
