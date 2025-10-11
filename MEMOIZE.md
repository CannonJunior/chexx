# Chexx Project Memoization

This file contains critical decisions and information that must be remembered across all development sessions.

---

## Port Configuration

**All web services for this project MUST use port 8888.**
- Web server: `http://localhost:8888`
- WebSocket server: `ws://localhost:8888`
- Never change this port without explicit user permission

---

## Multiplayer Networking Architecture (2025-10-10)

### Technology Stack Decision
- **Client:** Flutter + `web_socket_channel` package
- **Server:** Dart + `shelf` + `shelf_web_socket`
- **Protocol:** WebSocket with JSON messages
- **Architecture:** Client-Server (server-authoritative)

**Rationale:**
- Using Dart for both client and server enables code sharing (models, game logic)
- WebSocket provides real-time bidirectional communication
- Server-authoritative architecture prevents cheating and simplifies state management
- All technologies are free, open-source, and actively maintained

### Platform-Specific URL Configuration

**Development:**
- **Web/Desktop:** `ws://localhost:8888`
- **Android Emulator:** `ws://10.0.2.2:8888` (special IP to reach host machine)
- **Physical Android Device:** `ws://192.168.x.x:8888` (actual machine IP)
- **iOS Simulator:** `ws://localhost:8888`

**Production:**
- All platforms: `wss://chexx.yourdomain.com` (secure WebSocket)

### Android Configuration Requirements

**AndroidManifest.xml:**
```xml
<uses-permission android:name="android.permission.INTERNET" />
<application android:usesCleartextTraffic="true">
```

**Network Security Config (android/app/src/main/res/xml/network_security_config.xml):**
```xml
<domain-config cleartextTrafficPermitted="true">
  <domain includeSubdomains="true">10.0.2.2</domain>
</domain-config>
```

### iOS Configuration Requirements (Future)

**Info.plist additions:**
- `NSAppTransportSecurity` with allowance for localhost/development
- `NSLocalNetworkUsageDescription` for local network permission
- Background modes if needed for reconnection

### Server Deployment

**Development:** Self-hosted on localhost
**Production:** DigitalOcean Droplet ($4/month)
- 1 GB RAM, 1 vCPU sufficient for 5-10 concurrent games
- Use systemd for auto-restart
- Let's Encrypt for free SSL certificate
- Nginx reverse proxy for WebSocket

### iOS Development from Ubuntu

**Cannot build iOS apps directly on Linux.** Must use:
- **CI/CD Services:** GitHub Actions (free for public repos) or Codemagic ($333/month)
- **Remote Mac:** MacinCloud, AWS EC2 Mac instances
- **Cost:** $99/year Apple Developer Account required for App Store

**Recommendation:** Delay iOS until Android/Web/Desktop are stable.

### Local Multi-Instance Testing

**To test multiplayer on one machine:**
1. Run server: `dart run bin/server.dart`
2. Run multiple Flutter instances:
   - `flutter run -d chrome --web-port=8080`
   - `flutter run -d chrome --web-port=8081` (new browser profile)
   - `flutter run -d linux`
   - `flutter run -d emulator-5554` (Android)

### Message Types

Core network messages:
- `CREATE_SESSION`: Create game lobby
- `JOIN_SESSION`: Join existing lobby
- `START_GAME`: Begin game
- `PLAY_CARD`: Card action
- `UNIT_ACTION`: Unit movement/attack
- `END_TURN`: Complete turn
- `STATE_UPDATE`: Server sends game state
- `PLAYER_JOINED/LEFT`: Connection notifications
- `ERROR`: Error messages

### Critical Implementation Details

1. **Server is authoritative:** Clients send actions, server validates and broadcasts state
2. **Reconnection logic required:** Implement exponential backoff (1s, 2s, 4s, 8s, etc.)
3. **Heartbeat/ping-pong:** Send PING every 30 seconds to detect disconnections
4. **Session persistence:** Save session ID to local storage for reconnection
5. **Optimistic updates:** Show actions immediately, revert if server rejects

### Timeline Estimate

- Phases 1-5 (MVP): 5-7 weeks
- Phase 6 (Local testing): 1 week
- Phase 7 (Android): 1-2 weeks
- Phase 8 (Production): 1-2 weeks
- **Total:** 8-12 weeks

### Budget

- **Development:** $0
- **Production:** $4/month (server hosting)
- **iOS (optional):** $99/year + $0-333/month (CI/CD)

---

## Project Structure

```
chexx/
├── lib/           # Flutter client code
├── server/        # Dart server code (to be created)
├── shared/        # Shared models (to be created)
└── android/       # Android-specific configuration
```

---

## References

- Full implementation plan: `NETWORKING_IMPLEMENTATION_PLAN.md`
- Detailed networking research: `MULTIPLAYER_NETWORKING_RESEARCH.md`
- iOS deployment research: See agent output in conversation history

---

## Future Enhancements (Post-MVP)

- Push notifications for turn-based updates
- Lobby listing/matchmaking
- Spectator mode
- Game replay system
- Persistent game storage (database)
- Player accounts and statistics
- AI opponents for single-player
