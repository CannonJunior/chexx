# Chexx Game Server

WebSocket-based multiplayer game server for Chexx, built with Dart and Shelf.

## Phase 1 Complete ✅

**Server Foundation** - Basic WebSocket server with connection management and health checks.

### Features Implemented

- ✅ **WebSocket Server** on port 8888
- ✅ **Connection Manager** tracks all connected clients
- ✅ **Heartbeat System** (PING/PONG every 30 seconds)
- ✅ **CORS Middleware** for Flutter Web clients
- ✅ **Status Endpoint** for monitoring
- ✅ **Message Routing** with JSON protocol
- ✅ **Error Handling** with automatic cleanup

### Project Structure

```
server/
└── game_server/
    ├── bin/
    │   └── server.dart          # Main server file
    ├── pubspec.yaml             # Dependencies
    ├── test_client.html         # Browser-based test client
    └── README.md                # This file
```

### Installation

```bash
cd server/game_server
dart pub get
```

### Running the Server

```bash
dart run bin/server.dart
```

The server will start on port 8888:
- HTTP: `http://localhost:8888`
- WebSocket: `ws://localhost:8888/ws`
- Status: `http://localhost:8888/status`

### Testing

#### Option 1: Browser Test Client

1. Start the server
2. Open `test_client.html` in a browser
3. Click "Connect"
4. Try sending PING, ECHO, or custom messages

#### Option 2: curl (HTTP endpoints)

```bash
# Root endpoint
curl http://localhost:8888/

# Status endpoint
curl http://localhost:8888/status
```

#### Option 3: websocat (WebSocket CLI)

```bash
# Install websocat
cargo install websocat

# Connect to server
websocat ws://localhost:8888/ws

# Send a message
{"type": "PING"}
```

### Message Protocol

All messages are JSON objects with a `type` field.

#### Client → Server Messages

**PING**
```json
{
  "type": "PING",
  "timestamp": 1234567890
}
```

**PONG** (response to server PING)
```json
{
  "type": "PONG",
  "timestamp": 1234567890
}
```

**ECHO** (for testing)
```json
{
  "type": "ECHO",
  "payload": "your message here"
}
```

#### Server → Client Messages

**CONNECTED** (sent on connection)
```json
{
  "type": "CONNECTED",
  "clientId": "client_1234567890_0",
  "message": "Welcome to Chexx Game Server",
  "timestamp": 1234567890
}
```

**PING** (heartbeat)
```json
{
  "type": "PING",
  "timestamp": 1234567890
}
```

**PONG** (response to client PING)
```json
{
  "type": "PONG",
  "timestamp": 1234567890
}
```

**ECHO_RESPONSE**
```json
{
  "type": "ECHO_RESPONSE",
  "originalMessage": "your message",
  "timestamp": 1234567890
}
```

**ERROR**
```json
{
  "type": "ERROR",
  "message": "Error description"
}
```

### Dependencies

```yaml
dependencies:
  shelf: ^1.4.2              # HTTP server framework
  shelf_router: ^1.1.2       # Routing
  shelf_web_socket: ^1.0.4   # WebSocket support
```

### Architecture

**ConnectionManager**
- Tracks all connected clients with unique IDs
- Manages WebSocket channels
- Implements heartbeat/health checks
- Handles message routing
- Automatic cleanup on disconnect

**Server Features**
- Binds to `0.0.0.0` for all interfaces
- CORS enabled for cross-origin requests
- Request logging via Shelf middleware
- Error handling and graceful shutdown

### Next Steps (Phase 2)

- [ ] Create shared models package
- [ ] Add game session management
- [ ] Implement lobby system
- [ ] Add player authentication
- [ ] Integrate game state synchronization

### Configuration

**Environment Variables**
- `PORT`: Server port (default: 8888)

**Network Requirements**
- Open port 8888 (or configured port)
- For Android emulator: use `10.0.2.2:8888`
- For physical devices: use actual machine IP

### Troubleshooting

**Port Already in Use**
```bash
# Find process using port 8888
lsof -ti :8888

# Kill the process
kill <pid>
```

**Cannot Connect from Android Emulator**
- Use IP address `10.0.2.2` instead of `localhost`
- Check that server is bound to `0.0.0.0` (all interfaces)
- Verify firewall allows port 8888

**WebSocket Connection Fails**
- Check server is running: `curl http://localhost:8888/status`
- Verify CORS headers are present
- Check browser console for errors

### Development Notes

**Server Binding**
- Server binds to `InternetAddress.anyIPv4` (`0.0.0.0`)
- This allows connections from:
  - localhost
  - Other machines on network
  - Android emulators (via `10.0.2.2`)

**Heartbeat Implementation**
- Server sends PING every 30 seconds
- Client should respond with PONG
- Missing PONG doesn't disconnect (yet)
- Future: Implement timeout-based disconnect

**Client ID Generation**
- Format: `client_<timestamp>_<sequential_id>`
- Unique per connection
- Used for message routing

### Performance

**Current Limits**
- Tested with: 1-2 clients
- Expected capacity: 10-20 clients per server
- No load balancing implemented

**Optimization Opportunities**
- Add connection pooling
- Implement message batching
- Add compression for large messages
- Implement rate limiting

### Security Notes

**Development Mode**
- CORS allows all origins (`*`)
- No authentication required
- Cleartext WebSocket (ws://)

**Production TODO**
- Implement authentication
- Use secure WebSocket (wss://)
- Restrict CORS to specific origins
- Add rate limiting
- Implement input validation

---

## Changelog

**2025-10-10 - Phase 1 Complete**
- Initial server implementation
- WebSocket support with connection management
- Heartbeat system (PING/PONG)
- CORS middleware
- Status endpoint
- Test client HTML page

---

## License

Part of the Chexx game project.
