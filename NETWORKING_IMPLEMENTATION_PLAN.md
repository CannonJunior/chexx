# Chexx Multiplayer Networking Implementation Plan

**Date:** 2025-10-10
**Project:** Chexx - Hexagonal Turn-Based Strategy Game
**Objective:** Enable network multiplayer with cross-platform support (Web, Desktop, Android)
**Target:** 2-5 concurrent players per game session

---

## Executive Summary

This document outlines a comprehensive plan for implementing multiplayer networking in Chexx. The plan prioritizes:
- **Simple, maintainable architecture** using Dart on both client and server
- **Platform compatibility** across Web, Linux Desktop, and Android
- **Local testing capability** to run multiple instances on one machine
- **Zero-cost development** with low-cost production deployment
- **Future iOS support** with minimal rework required

**Recommended Technology Stack:**
- **Client:** Flutter + `web_socket_channel` package
- **Server:** Dart + `shelf` + `shelf_web_socket`
- **Protocol:** WebSocket with JSON message format
- **Architecture:** Client-Server (server-authoritative game state)

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Implementation Phases](#2-implementation-phases)
3. [Platform-Specific Considerations](#3-platform-specific-considerations)
4. [Technical Issues and Solutions](#4-technical-issues-and-solutions)
5. [Testing Strategy](#5-testing-strategy)
6. [Deployment Plan](#6-deployment-plan)
7. [iOS Considerations (Future)](#7-ios-considerations-future)
8. [Risk Assessment](#8-risk-assessment)

---

## 1. Architecture Overview

### 1.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Game Server                         │
│                    (Dart + Shelf)                       │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ Game Session │  │ Game Session │  │ Game Session │ │
│  │   Manager    │  │   Manager    │  │   Manager    │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │        WebSocket Connection Manager              │  │
│  └──────────────────────────────────────────────────┘  │
└───────────────────────┬─────────────────────────────────┘
                        │ WebSocket (Port 8888)
          ┌─────────────┼─────────────┐
          │             │             │
    ┌─────▼─────┐ ┌─────▼─────┐ ┌───▼───────┐
    │  Player 1  │ │  Player 2  │ │ Player 3  │
    │  (Web)     │ │  (Desktop) │ │ (Android) │
    └────────────┘ └────────────┘ └───────────┘
```

### 1.2 Message Flow

**Turn-Based Game Loop:**
1. **Player Action:** Client sends action (play card, move unit, etc.)
2. **Server Validation:** Server validates action against game rules
3. **State Update:** Server updates authoritative game state
4. **Broadcast:** Server broadcasts updated state to all players
5. **Client Render:** Clients update UI based on new state

### 1.3 Server Responsibilities (Authoritative)

- **Game State Management:** Single source of truth for game state
- **Input Validation:** Ensure all moves are legal
- **Turn Management:** Control whose turn it is
- **Player Connection Tracking:** Handle connect/disconnect/reconnect
- **Session Management:** Create/join/leave game lobbies
- **Persistence:** Save game state for reconnection scenarios

### 1.4 Client Responsibilities

- **UI Rendering:** Display game board and cards
- **Input Handling:** Capture player actions
- **State Synchronization:** Apply server state updates
- **Connection Management:** Maintain WebSocket connection
- **Local Validation:** Provide immediate feedback (before server confirms)

---

## 2. Implementation Phases

### Phase 1: Server Foundation (Week 1-2)

**Goal:** Create basic Dart server with WebSocket support

**Tasks:**
1. ✅ Create `server/` directory in project root
2. ✅ Initialize Dart server project
   ```bash
   cd server
   dart create -t server-shelf game_server
   ```
3. ✅ Add dependencies to `pubspec.yaml`:
   ```yaml
   dependencies:
     shelf: ^1.4.0
     shelf_web_socket: ^1.0.4
     shelf_router: ^1.1.4
   ```
4. ✅ Implement basic WebSocket server
5. ✅ Create connection manager to track clients
6. ✅ Implement ping/pong for connection health checks
7. ✅ Test server can accept connections from localhost

**Deliverable:** Server that accepts WebSocket connections and echoes messages back

**Testing:** Use `websocat` CLI tool or browser console to test connections

---

### Phase 2: Shared Models (Week 2-3)

**Goal:** Create shared data models between client and server

**Approach:**
- Create `shared/` directory for models used by both client and server
- Use JSON serialization for network communication
- Share models via pub package or direct path dependency

**Tasks:**
1. ✅ Create `shared/lib/models/` directory
2. ✅ Port existing game models to shared package:
   - `GameState`
   - `SimpleGameUnit`
   - `CardAction`
   - `Player`
   - `HexCoordinate`
3. ✅ Add JSON serialization (`toJson`/`fromJson` methods)
4. ✅ Create network message wrapper:
   ```dart
   class NetworkMessage {
     final String type;
     final Map<String, dynamic> payload;
     final String? sessionId;
     final String? playerId;

     NetworkMessage({
       required this.type,
       required this.payload,
       this.sessionId,
       this.playerId,
     });

     Map<String, dynamic> toJson() => {
       'type': type,
       'payload': payload,
       'sessionId': sessionId,
       'playerId': playerId,
     };

     factory NetworkMessage.fromJson(Map<String, dynamic> json) {
       return NetworkMessage(
         type: json['type'] as String,
         payload: json['payload'] as Map<String, dynamic>,
         sessionId: json['sessionId'] as String?,
         playerId: json['playerId'] as String?,
       );
     }
   }
   ```

**Message Types:**
- `CREATE_SESSION`: Create new game lobby
- `JOIN_SESSION`: Join existing game lobby
- `START_GAME`: Begin game from lobby
- `PLAY_CARD`: Play a card action
- `UNIT_ACTION`: Move/attack with unit
- `END_TURN`: Complete current player's turn
- `STATE_UPDATE`: Server sends full game state
- `PLAYER_JOINED`: Notify players of new player
- `PLAYER_LEFT`: Notify players of disconnect
- `ERROR`: Error message from server

**Deliverable:** Shared package with all game models and network messages

---

### Phase 3: Client Network Layer (Week 3-4)

**Goal:** Integrate WebSocket client into Flutter app

**Tasks:**
1. ✅ Add dependency to Flutter `pubspec.yaml`:
   ```yaml
   dependencies:
     web_socket_channel: ^3.0.0
   ```
2. ✅ Create `NetworkManager` class:
   ```dart
   class NetworkManager extends ChangeNotifier {
     WebSocketChannel? _channel;
     String? _sessionId;
     String? _playerId;

     // Platform-aware URL configuration
     String get serverUrl {
       if (Platform.isAndroid) {
         return 'ws://10.0.2.2:8888'; // Android emulator special IP
       } else {
         return 'ws://localhost:8888'; // Desktop/iOS/physical devices
       }
     }

     Future<void> connect() async {
       _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
       _channel!.stream.listen(
         _onMessage,
         onError: _onError,
         onDone: _onDisconnect,
       );
     }

     void sendMessage(NetworkMessage message) {
       final json = jsonEncode(message.toJson());
       _channel?.sink.add(json);
     }

     void _onMessage(dynamic data) {
       final json = jsonDecode(data as String);
       final message = NetworkMessage.fromJson(json);
       // Handle based on message type
     }

     void _onError(error) {
       print('WebSocket error: $error');
       _reconnect();
     }

     void _onDisconnect() {
       print('WebSocket disconnected');
       _reconnect();
     }

     Future<void> _reconnect() async {
       await Future.delayed(Duration(seconds: 5));
       connect();
     }
   }
   ```
3. ✅ Implement reconnection logic with exponential backoff
4. ✅ Add to Provider for state management
5. ✅ Test connection from Flutter Web and Desktop

**Deliverable:** Flutter app can connect to server and send/receive messages

---

### Phase 4: Game Lobby System (Week 4-5)

**Goal:** Implement matchmaking/lobby system

**Server Tasks:**
1. ✅ Create `GameLobby` class to hold waiting players
2. ✅ Implement lobby creation (assign unique session ID)
3. ✅ Implement lobby joining (validate session ID, check capacity)
4. ✅ Implement lobby listing (for public lobbies)
5. ✅ Add lobby state: `waiting`, `starting`, `in_progress`, `completed`
6. ✅ Handle player disconnect in lobby (remove from waiting list)

**Client Tasks:**
1. ✅ Create lobby UI screen
2. ✅ Implement "Create Game" button
3. ✅ Implement "Join Game" with session ID input
4. ✅ Display waiting players in lobby
5. ✅ Add "Start Game" button (for game creator)
6. ✅ Handle lobby events (player joined/left)

**Deliverable:** Players can create lobbies, join via session ID, and start games

---

### Phase 5: Game State Synchronization (Week 5-7)

**Goal:** Synchronize game state between server and clients

**Server Tasks:**
1. ✅ Implement server-side game logic:
   - Copy existing `ChexxGameState` logic to server
   - Validate all actions before applying
   - Maintain authoritative game state
2. ✅ Handle action messages:
   - `PLAY_CARD`: Validate card ownership and action legality
   - `UNIT_ACTION`: Validate unit ownership and movement/attack rules
   - `END_TURN`: Advance turn, reset state, notify all players
3. ✅ Broadcast state updates after each action
4. ✅ Implement full state snapshots for reconnecting players

**Client Tasks:**
1. ✅ Modify `ChexxGameState` to accept state from server
2. ✅ Disable local game logic (server is authoritative)
3. ✅ Send action messages instead of directly modifying state
4. ✅ Apply state updates from server
5. ✅ Handle latency (show loading indicators during server processing)
6. ✅ Implement optimistic UI updates (show action immediately, revert if server rejects)

**Critical Implementation Detail:**

**Current Architecture (Local):**
```dart
// Player clicks hex → immediate state update
void onHexTapped(HexCoordinate coord) {
  if (canMoveToHex(coord)) {
    moveUnit(selectedUnit, coord); // Updates state immediately
    notifyListeners();
  }
}
```

**New Architecture (Networked):**
```dart
// Player clicks hex → send to server → wait for confirmation
void onHexTapped(HexCoordinate coord) {
  if (canMoveToHex(coord)) {
    // Optimistic update (visual feedback)
    _pendingAction = PendingAction.move(selectedUnit, coord);
    notifyListeners();

    // Send to server
    networkManager.sendMessage(NetworkMessage(
      type: 'UNIT_ACTION',
      payload: {
        'action': 'move',
        'unitId': selectedUnit.id,
        'target': coord.toJson(),
      },
    ));
  }
}

// When server confirms
void _onStateUpdate(NetworkMessage message) {
  _pendingAction = null;
  final newState = GameState.fromJson(message.payload);
  _applyServerState(newState);
  notifyListeners();
}

// If server rejects
void _onError(NetworkMessage message) {
  _pendingAction = null; // Revert optimistic update
  _showError(message.payload['message']);
  notifyListeners();
}
```

**Deliverable:** Complete game playable over network with multiple players

---

### Phase 6: Local Multi-Instance Testing (Week 7-8)

**Goal:** Enable testing with multiple players on one machine

**Setup:**
1. ✅ Configure server to bind to `0.0.0.0:8888` (accept all interfaces)
2. ✅ Run server: `dart run bin/server.dart`
3. ✅ Launch multiple Flutter instances:
   - **Web Instance 1:** `flutter run -d chrome --web-port=8080`
   - **Web Instance 2:** `flutter run -d chrome --web-port=8081`
   - **Desktop Instance:** `flutter run -d linux`
   - **Android Emulator:** Configure special IP `10.0.2.2`

**Testing Scenarios:**
1. ✅ Two players (Web + Desktop) in same game
2. ✅ Player 1 plays card → Player 2 sees update
3. ✅ Player disconnects → reconnects → rejoins game
4. ✅ Full game completion with turn rotation

**Tools:**
- **Port Management:** Use different web ports for multiple browser instances
- **Session Management:** Copy session IDs between instances for joining
- **Debugging:** Server logs show all player actions

**Deliverable:** Documented process for local multi-player testing

---

### Phase 7: Android Emulator Support (Week 8-9)

**Goal:** Ensure Android emulator can connect to local server

**Android-Specific Configuration:**

**1. Network Permissions (`android/app/src/main/AndroidManifest.xml`):**
```xml
<manifest>
  <uses-permission android:name="android.permission.INTERNET" />
  <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

  <application>
    <!-- Allow cleartext traffic for development -->
    android:usesCleartextTraffic="true"
  </application>
</manifest>
```

**2. Network Security Config (for production with HTTP in development):**

Create `android/app/src/main/res/xml/network_security_config.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
  <!-- Allow cleartext traffic to localhost for development -->
  <domain-config cleartextTrafficPermitted="true">
    <domain includeSubdomains="true">10.0.2.2</domain>
    <domain includeSubdomains="true">localhost</domain>
  </domain-config>
</network-security-config>
```

Reference in `AndroidManifest.xml`:
```xml
<application
  android:networkSecurityConfig="@xml/network_security_config">
```

**3. Platform-Aware URL Configuration:**
```dart
class NetworkConfig {
  static String get serverUrl {
    if (Platform.isAndroid) {
      // Check if running in emulator
      return 'ws://10.0.2.2:8888';
    } else if (Platform.isIOS) {
      // iOS simulator
      return 'ws://localhost:8888';
    } else {
      // Desktop or physical devices
      return 'ws://localhost:8888';
    }
  }

  // For production (using real server IP)
  static String get productionUrl {
    return 'wss://chexx-server.example.com';
  }
}
```

**Android Emulator Special IPs:**
- `10.0.2.2`: Host machine's `localhost`
- `10.0.2.3`: First DNS server
- `10.0.2.15`: Emulator's own network address
- For emulator-to-emulator: Use actual machine IP (`192.168.x.x`)

**Testing:**
1. ✅ Start server on host machine
2. ✅ Launch Android emulator
3. ✅ Run Flutter app on emulator
4. ✅ Verify connection to `10.0.2.2:8888`
5. ✅ Test with desktop/web client simultaneously

**Common Issues:**
- **Cannot connect:** Check firewall allows port 8888
- **Connection refused:** Ensure server binds to `0.0.0.0` not `127.0.0.1`
- **Timeout:** Check `android:usesCleartextTraffic="true"` is set

**Deliverable:** Android emulator successfully connects to local development server

---

### Phase 8: Production Deployment (Week 9-10)

**Goal:** Deploy server to production hosting

**Hosting Options:**

**Development (Free):**
- Self-hosted on development machine
- Only accessible within local network
- Good for initial testing

**Production ($0-5/month):**

**Option 1: DigitalOcean Droplet ($4/month)**
- 1 GB RAM, 1 vCPU, 25 GB SSD
- Sufficient for 5-10 concurrent games
- Full control over server
- Simple Dart server deployment

**Setup:**
```bash
# On DigitalOcean droplet
apt-get update
apt-get install -y dart

# Deploy server
git clone https://github.com/yourrepo/chexx-server
cd chexx-server
dart pub get
dart compile exe bin/server.dart -o server

# Run with systemd service
sudo systemctl enable chexx-server
sudo systemctl start chexx-server
```

**Option 2: Firebase/Supabase Realtime Database (Free tier)**
- No server code needed
- Managed infrastructure
- Built-in authentication
- Real-time synchronization
- Free tier: Sufficient for 5 concurrent users

**Trade-off:** Less control over game logic, but zero maintenance

**Option 3: AWS Lambda + API Gateway (Serverless - $0 for low traffic)**
- Pay only for actual usage
- Automatic scaling
- More complex setup

**Recommended for Chexx:** Start with **DigitalOcean** ($4/month) for simplicity and full control

**Client Configuration:**
```dart
class NetworkConfig {
  static const bool isProduction = bool.fromEnvironment('PRODUCTION', defaultValue: false);

  static String get serverUrl {
    if (isProduction) {
      return 'wss://chexx.yourdomain.com';
    }

    // Development
    if (Platform.isAndroid) {
      return 'ws://10.0.2.2:8888';
    }
    return 'ws://localhost:8888';
  }
}
```

**Build for production:**
```bash
flutter build web --dart-define=PRODUCTION=true
flutter build apk --dart-define=PRODUCTION=true
flutter build linux --dart-define=PRODUCTION=true
```

**Deliverable:** Server deployed and accessible from internet; clients can connect

---

## 3. Platform-Specific Considerations

### 3.1 Flutter Web

**Challenges:**
- **CORS (Cross-Origin Resource Sharing):** Browser security blocks WebSocket connections to different origins
- **Same-Origin Policy:** Must serve from same domain or configure CORS

**Solutions:**

**1. Development: CORS Middleware on Server**
```dart
import 'package:shelf/shelf.dart';

Middleware cors() {
  return (Handler handler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }

      final response = await handler(request);
      return response.change(headers: _corsHeaders);
    };
  };
}

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type',
};
```

**2. Production: Reverse Proxy with Nginx**
- Serve Flutter web app and WebSocket server through same domain
- Nginx proxies WebSocket connections to Dart server

**Browser Compatibility:**
- All modern browsers support WebSocket
- No special configuration needed on client side

**Testing:**
- Use `--web-renderer canvaskit` for better rendering (not required for networking)
- Test in Chrome DevTools → Network tab to see WebSocket traffic

---

### 3.2 Linux Desktop

**Advantages:**
- No special permissions needed
- Full WebSocket support
- Easiest platform for development and testing

**Configuration:**
```dart
// No special configuration needed
final channel = IOWebSocketChannel.connect('ws://localhost:8888');
```

**Testing:**
- Run multiple instances with different window positions
- Use `flutter run -d linux` from different terminals

---

### 3.3 Android

**Key Differences:**
- **Emulator IP:** Must use `10.0.2.2` to reach host machine's localhost
- **Physical Device:** Must use actual machine IP (e.g., `192.168.1.100`)
- **Permissions:** Requires `INTERNET` permission in manifest
- **Cleartext Traffic:** Must enable for HTTP/WS in development

**Configuration (covered in Phase 7):**
- AndroidManifest.xml permissions
- Network security config
- Platform-aware URL selection

**Testing:**
- Use Android Studio emulator
- Test with physical device on same Wi-Fi network
- Monitor logs: `flutter logs` or Android Studio Logcat

**Production:**
- Use WSS (WebSocket Secure) with valid SSL certificate
- Remove cleartext traffic allowance
- Test on various Android versions (API 21+)

---

### 3.4 iOS (Future Support)

**iOS Development from Ubuntu Challenges:**
- Cannot build iOS apps directly on Linux
- Must use CI/CD services (Codemagic, GitHub Actions) or remote Mac

**Networking Considerations:**

**1. App Transport Security (ATS):**
- iOS enforces HTTPS/WSS by default
- For development with HTTP/WS, must configure Info.plist:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

**2. Background WebSocket Limitations:**
- iOS suspends WebSocket connections when app goes to background
- Must implement reconnection when app returns to foreground
- Consider push notifications for turn-based game updates

**3. Local Network Permission (iOS 14+):**
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Connect to local game server for multiplayer</string>
```

**4. WebSocket Support:**
- Full WebSocket support in iOS Safari and WKWebView
- No special client-side configuration for basic WebSocket

**Deployment Strategy:**
1. Develop and test on Android/Desktop/Web
2. When ready for iOS:
   - Set up Codemagic or GitHub Actions for iOS builds
   - Configure Info.plist for networking
   - Test on iOS simulator via CI/CD
   - Deploy to TestFlight for beta testing

**Cost:**
- Apple Developer Account: $99/year (required for App Store)
- CI/CD: Free (GitHub Actions for open source) or ~$333/month (Codemagic)

**Recommended Approach:**
- Delay iOS implementation until core networking is stable on other platforms
- Use GitHub Actions (free for public repos) for iOS builds
- Budget 1-2 weeks for iOS-specific adjustments

---

## 4. Technical Issues and Solutions

### 4.1 Connection Management

**Issue:** WebSocket connections can drop due to network issues, app backgrounding, or server restarts

**Solutions:**

**1. Heartbeat/Ping-Pong:**
```dart
// Client-side
class NetworkManager {
  Timer? _heartbeatTimer;

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(Duration(seconds: 30), (_) {
      sendMessage(NetworkMessage(type: 'PING', payload: {}));
    });
  }

  void _onPong() {
    // Reset timeout counter
  }
}

// Server-side
void handlePing(WebSocket socket) {
  socket.add(jsonEncode({'type': 'PONG'}));
}
```

**2. Exponential Backoff Reconnection:**
```dart
class ReconnectionStrategy {
  int _attemptCount = 0;
  final int maxAttempts = 10;
  final Duration baseDelay = Duration(seconds: 1);

  Duration get nextDelay {
    final delay = baseDelay * math.pow(2, _attemptCount);
    _attemptCount++;
    return delay.clamp(baseDelay, Duration(minutes: 5));
  }

  void reset() {
    _attemptCount = 0;
  }
}
```

**3. Session Persistence:**
```dart
// Save session ID to local storage
class SessionManager {
  Future<void> saveSession(String sessionId, String playerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_id', sessionId);
    await prefs.setString('player_id', playerId);
  }

  Future<SessionInfo?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');
    final playerId = prefs.getString('player_id');
    if (sessionId != null && playerId != null) {
      return SessionInfo(sessionId, playerId);
    }
    return null;
  }
}
```

---

### 4.2 State Synchronization

**Issue:** Client and server state can diverge due to network latency or packet loss

**Solutions:**

**1. Server as Single Source of Truth:**
- Server maintains authoritative game state
- Clients send actions, not state changes
- Server validates and applies actions
- Server broadcasts resulting state

**2. Full State Snapshots:**
```dart
// Periodically send full state (not just deltas)
class GameSession {
  void _sendFullStateSnapshot() {
    final state = gameState.toJson();
    broadcast(NetworkMessage(
      type: 'STATE_UPDATE',
      payload: state,
    ));
  }
}
```

**3. Action Sequence Numbers:**
```dart
class GameAction {
  final int sequenceNumber;
  final String playerId;
  final String action;
  final Map<String, dynamic> data;
}

// Server checks sequence numbers to detect missing actions
```

**4. Optimistic Updates with Rollback:**
```dart
class OptimisticUpdateManager {
  GameState _confirmedState;
  GameState _optimisticState;
  PendingAction? _pendingAction;

  void applyOptimisticUpdate(Action action) {
    _pendingAction = PendingAction(action, _confirmedState.clone());
    _optimisticState = _confirmedState.clone();
    _optimisticState.apply(action);
  }

  void confirmUpdate(GameState serverState) {
    _confirmedState = serverState;
    _optimisticState = serverState;
    _pendingAction = null;
  }

  void rollbackUpdate() {
    _optimisticState = _confirmedState;
    _pendingAction = null;
  }
}
```

---

### 4.3 Latency and Responsiveness

**Issue:** Network latency makes game feel sluggish

**Solutions:**

**1. Optimistic UI Updates (as shown above)**
- Show action immediately on client
- Revert if server rejects

**2. Loading Indicators:**
```dart
class GameUI extends StatelessWidget {
  final bool isWaitingForServer;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GameBoard(),
        if (isWaitingForServer)
          Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
```

**3. Action Queueing:**
- Allow players to queue multiple actions
- Send to server as batch
- Reduces perceived latency for multi-action turns

**4. Local Validation:**
```dart
// Validate actions locally before sending to server
// Provides immediate feedback for invalid actions
bool canPlayCard(Card card) {
  if (!myHand.contains(card)) return false;
  if (!isMyTurn) return false;
  if (card.cost > currentMana) return false;
  return true;
}

void playCard(Card card) {
  if (!canPlayCard(card)) {
    showError('Cannot play this card');
    return;
  }

  // Send to server
  networkManager.sendAction(PlayCardAction(card));
}
```

---

### 4.4 Android Emulator Networking

**Issue 1: Cannot connect to localhost**

**Solution:** Use special IP `10.0.2.2`

```dart
String get serverUrl {
  if (Platform.isAndroid) {
    // Detect if running in emulator vs physical device
    // Emulator: use 10.0.2.2
    // Physical device: use actual server IP
    return 'ws://10.0.2.2:8888';
  }
  return 'ws://localhost:8888';
}
```

**Issue 2: Cleartext traffic blocked**

**Solution:** Configure network security (covered in Phase 7)

**Issue 3: Connection timeout**

**Possible Causes:**
- Firewall blocking port 8888 on host machine
- Server not binding to all interfaces (`0.0.0.0`)
- Android app doesn't have INTERNET permission

**Debug Steps:**
1. Test server from browser: `http://localhost:8888`
2. Check firewall: `sudo ufw status`
3. Check server binding: `netstat -tuln | grep 8888`
4. Check Android logs: `flutter logs`

---

### 4.5 Production Deployment Issues

**Issue 1: Port 80/443 already in use**

**Solution:** Use reverse proxy (Nginx) or non-standard port

**Issue 2: SSL certificate for WSS**

**Solution:** Use Let's Encrypt (free) or Cloudflare (free tier)
```bash
# Let's Encrypt with certbot
sudo certbot --nginx -d chexx.yourdomain.com
```

**Issue 3: Firewall configuration**

**Solution:** Open required ports
```bash
sudo ufw allow 8888/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

**Issue 4: Server crashes/restarts**

**Solution:** Use systemd for automatic restart
```ini
[Unit]
Description=Chexx Game Server
After=network.target

[Service]
Type=simple
User=chexx
WorkingDirectory=/home/chexx/server
ExecStart=/usr/bin/dart run bin/server.dart
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

---

## 5. Testing Strategy

### 5.1 Local Development Testing

**Setup:**
1. Run server: `dart run bin/server.dart`
2. Run clients:
   - Web 1: `flutter run -d chrome --web-port=8080`
   - Web 2: `flutter run -d chrome --web-port=8081` (new Chrome profile)
   - Desktop: `flutter run -d linux`
   - Android: `flutter run -d emulator-5554`

**Test Cases:**
1. ✅ **Connection Test**
   - All clients can connect to server
   - Connection status displayed in UI

2. ✅ **Lobby Test**
   - Player 1 creates game (receives session ID)
   - Player 2 joins with session ID
   - Both players see each other in lobby
   - Player 1 starts game

3. ✅ **Turn-Based Gameplay**
   - Player 1's turn: Play card, move unit
   - Player 2 sees Player 1's actions
   - Player 1 ends turn
   - Player 2's turn begins

4. ✅ **Disconnection Test**
   - Player 1 disconnects (close app)
   - Player 2 sees "Player 1 disconnected"
   - Player 1 reconnects
   - Player 1 sees current game state

5. ✅ **Error Handling**
   - Player 1 attempts invalid move (out of turn)
   - Server rejects, Player 1 sees error
   - Player 1 attempts valid move
   - Move succeeds

6. ✅ **Full Game Completion**
   - Play game to completion
   - Winner determined
   - Both players see game over screen

### 5.2 Automated Testing

**Unit Tests:**
```dart
// Test message serialization
test('NetworkMessage JSON roundtrip', () {
  final message = NetworkMessage(
    type: 'PLAY_CARD',
    payload: {'cardId': '123'},
  );
  final json = message.toJson();
  final decoded = NetworkMessage.fromJson(json);
  expect(decoded.type, message.type);
  expect(decoded.payload, message.payload);
});

// Test server game logic
test('Server validates player ownership', () {
  final game = GameSession();
  final player1 = game.addPlayer('Player1');
  final player2 = game.addPlayer('Player2');

  // Player 1's turn
  expect(game.currentPlayer, player1);

  // Player 2 tries to act (should fail)
  final result = game.handleAction(player2, MoveAction(...));
  expect(result.success, false);
  expect(result.error, 'Not your turn');
});
```

**Integration Tests:**
```dart
// Test client-server interaction
testWidgets('Client can join game session', (tester) async {
  // Start test server
  final server = await TestServer.start();

  // Launch client
  await tester.pumpWidget(ChexxApp(serverUrl: server.url));

  // Create game
  await tester.tap(find.text('Create Game'));
  await tester.pumpAndSettle();

  // Verify session ID displayed
  expect(find.textContaining('Session:'), findsOneWidget);

  // Cleanup
  await server.stop();
});
```

### 5.3 Performance Testing

**Metrics to Monitor:**
- **Latency:** Measure roundtrip time for actions (should be <200ms on local network)
- **Throughput:** Number of messages per second server can handle
- **Memory:** Server memory usage with multiple games active
- **CPU:** Server CPU usage under load

**Load Testing:**
```dart
// Simulate multiple clients
Future<void> loadTest() async {
  final clients = <WebSocket>[];

  // Create 10 concurrent games (20 clients)
  for (int i = 0; i < 20; i++) {
    final ws = await WebSocket.connect('ws://localhost:8888');
    clients.add(ws);
  }

  // Send actions continuously
  for (int i = 0; i < 1000; i++) {
    final client = clients[i % clients.length];
    client.add(jsonEncode({'type': 'PING'}));
    await Future.delayed(Duration(milliseconds: 10));
  }

  // Measure response times
}
```

**Target Performance:**
- 5 concurrent games (10 players)
- <100ms server response time
- <50 MB server memory usage
- <10% CPU usage on modest hardware

---

## 6. Deployment Plan

### 6.1 Development Environment

**Local Development:**
- Server: `dart run bin/server.dart`
- Clients: Multiple Flutter instances on localhost

**No deployment needed** - all running on development machine

### 6.2 Staging Environment (Optional)

**DigitalOcean Droplet ($4/month):**
- Deploy server to cloud
- Test with real internet latency
- Invite beta testers

**Setup:**
```bash
# SSH into droplet
ssh root@your-droplet-ip

# Install dependencies
apt-get update
apt-get install -y dart nginx certbot

# Clone repository
git clone https://github.com/youruser/chexx-server
cd chexx-server
dart pub get

# Compile server
dart compile exe bin/server.dart -o chexx-server

# Create systemd service (see Phase 8)
```

### 6.3 Production Environment

**Same as Staging** but with:
- SSL certificate (Let's Encrypt)
- Reverse proxy (Nginx) for WebSocket
- Monitoring (simple logging or Datadog free tier)
- Backups (DigitalOcean snapshots)

**Nginx Configuration:**
```nginx
server {
    listen 80;
    server_name chexx.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name chexx.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/chexx.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/chexx.yourdomain.com/privkey.pem;

    location /ws {
        proxy_pass http://localhost:8888;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }

    location / {
        root /var/www/chexx;
        try_files $uri /index.html;
    }
}
```

**Client Configuration:**
```dart
static String get serverUrl {
  if (kDebugMode) {
    // Development
    if (Platform.isAndroid) return 'ws://10.0.2.2:8888';
    return 'ws://localhost:8888';
  }
  // Production
  return 'wss://chexx.yourdomain.com/ws';
}
```

**Deployment Workflow:**
1. Develop locally
2. Push to GitHub
3. SSH into server
4. `git pull`
5. `dart compile exe bin/server.dart -o chexx-server`
6. `sudo systemctl restart chexx-server`

**Future: Automated CI/CD**
- GitHub Actions triggers on push to `main`
- Runs tests
- Builds server
- Deploys to DigitalOcean via SSH
- Restarts service

---

## 7. iOS Considerations (Future)

### 7.1 Development Without Mac

**Challenge:** Cannot build/test iOS apps on Linux

**Solutions:**

**Option 1: GitHub Actions (Recommended for Open Source)**
- Free macOS runners for public repositories
- 200 macOS minutes per month on free plan (10x multiplier)
- Automate iOS builds and TestFlight deployment

**.github/workflows/ios.yml:**
```yaml
name: iOS Build

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'

      - name: Install dependencies
        run: flutter pub get

      - name: Build iOS
        run: flutter build ios --release --no-codesign

      - name: Upload artifact
        uses: actions/upload-artifact@v3
        with:
          name: ios-build
          path: build/ios/iphoneos/Runner.app
```

**Option 2: Codemagic (Paid)**
- $333/month for team plan
- Automatic code signing
- Faster builds than GitHub Actions
- TestFlight/App Store upload automation

**Option 3: Remote Mac Services**
- MacinCloud: Pay-as-you-go
- AWS EC2 Mac instances: 24-hour minimum
- For occasional testing/debugging

**Recommendation:** Start with GitHub Actions, upgrade to Codemagic if build frequency increases

### 7.2 iOS Networking Configuration

**Info.plist Changes:**

**1. App Transport Security (Development):**
```xml
<!-- Allow HTTP/WS for development -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>10.0.2.2</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
        <key>localhost</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

**2. Local Network Permission (iOS 14+):**
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Connect to local game server for multiplayer</string>
```

**3. Background Modes (if needed):**
```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
</array>
```

### 7.3 iOS-Specific Code

**Background Reconnection:**
```dart
class IOSNetworkManager extends NetworkManager {
  @override
  void initState() {
    super.initState();

    // Listen for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reconnect when app returns to foreground
      if (!isConnected) {
        connect();
      }
    } else if (state == AppLifecycleState.paused) {
      // Prepare for disconnect
      _onAppBackgrounded();
    }
  }
}
```

### 7.4 iOS Testing Strategy

**Without Physical iOS Device:**
1. **Simulator via CI/CD:** Run integration tests on GitHub Actions macOS runner
2. **Cloud Testing:** Use BrowserStack for real device testing
3. **Beta Testers:** Deploy to TestFlight, recruit iOS users to test

**With Physical iOS Device:**
- Free Apple Developer account allows 7-day device testing
- Must rebuild every 7 days
- Good for development testing

### 7.5 iOS Deployment Timeline

**Estimated Timeline:**
- **Week 1:** Set up GitHub Actions or Codemagic
- **Week 2:** Configure Info.plist, add iOS-specific code
- **Week 3:** Test on iOS Simulator via CI/CD
- **Week 4:** Deploy to TestFlight, beta testing
- **Week 5:** Fix iOS-specific bugs
- **Week 6:** App Store submission

**Cost Breakdown:**
- Apple Developer Account: $99/year (one-time)
- CI/CD: $0 (GitHub Actions free tier) or $333/month (Codemagic)
- Cloud Testing: $0-$40/month (BrowserStack if needed)

**Recommendation:**
- Delay iOS until core game is stable on Android/Web/Desktop
- Budget $99 + 1-2 months development time
- Use GitHub Actions for cost savings

---

## 8. Risk Assessment

### 8.1 Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| WebSocket connection instability | Medium | High | Implement robust reconnection logic with exponential backoff |
| State synchronization bugs | High | High | Use server as single source of truth; full state snapshots |
| Android emulator networking issues | Medium | Medium | Thorough documentation; test on multiple emulator versions |
| iOS deployment complexity | High | Low | Delay iOS until other platforms stable; use CI/CD |
| Production server downtime | Low | High | Use DigitalOcean monitoring; set up alerts; systemd auto-restart |
| SSL certificate expiration | Low | Medium | Use Let's Encrypt auto-renewal; calendar reminders |

### 8.2 Schedule Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Scope creep (adding features) | High | Medium | Stick to phases; mark additional features as "Phase 9+" |
| Underestimated complexity | Medium | Medium | Build buffer time into estimates; prioritize MVP |
| Debugging network issues takes longer than expected | Medium | Medium | Allocate full week for Phase 8 (Android testing) |
| iOS deployment blocked by Apple | Low | Low | Not critical; can delay indefinitely |

### 8.3 Cost Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Hosting costs exceed budget | Low | Low | Start with $4/month DigitalOcean; monitor usage |
| iOS development requires paid CI/CD | Medium | Medium | Use GitHub Actions free tier first; upgrade only if needed |
| Need multiple physical test devices | Low | Low | Use emulators/simulators; cloud testing services |

### 8.4 User Experience Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| High latency ruins gameplay | Medium | High | Implement optimistic updates; test on various networks |
| Disconnections frustrate users | Medium | High | Auto-reconnection; save game state; resume gracefully |
| Complex lobby system confuses users | Low | Medium | Simple UI; clear instructions; session ID copy/paste |
| Players can't find each other | Medium | Medium | Consider adding lobby list or matchmaking in future |

---

## 9. Success Criteria

### Phase Completion Criteria

**Phase 1 (Server Foundation):**
- ✅ Server accepts WebSocket connections
- ✅ Ping/pong health checks work
- ✅ Can test with websocat or browser console

**Phase 2 (Shared Models):**
- ✅ All game models have JSON serialization
- ✅ NetworkMessage wrapper created
- ✅ Models shared between client and server

**Phase 3 (Client Network Layer):**
- ✅ Flutter app connects to server
- ✅ Can send/receive messages
- ✅ Reconnection logic works

**Phase 4 (Lobby System):**
- ✅ Can create game lobbies
- ✅ Can join with session ID
- ✅ Can start game from lobby

**Phase 5 (Game State Sync):**
- ✅ Full game playable over network
- ✅ Multiple players see synchronized state
- ✅ Turn rotation works correctly

**Phase 6 (Local Testing):**
- ✅ Can run 2+ clients on same machine
- ✅ Full game playable between instances
- ✅ Testing process documented

**Phase 7 (Android Support):**
- ✅ Android emulator connects to local server
- ✅ Android app playable over network
- ✅ Works with desktop/web clients

**Phase 8 (Production Deployment):**
- ✅ Server deployed to DigitalOcean
- ✅ Clients can connect from internet
- ✅ SSL certificate configured (WSS)

### Overall Success Metrics

**Technical:**
- 95%+ uptime for game server
- <200ms action response time (local network)
- <500ms action response time (internet)
- Zero data loss on disconnection/reconnection

**User Experience:**
- Players can find and join games within 30 seconds
- Games feel responsive despite network latency
- Disconnections handled gracefully (can rejoin)
- Error messages clear and actionable

**Business:**
- $5/month or less operating cost
- Can support 5 concurrent games (10 players)
- Can scale to 10-20 games with minimal cost increase

---

## 10. Conclusion

This plan provides a comprehensive roadmap for implementing multiplayer networking in Chexx. The phased approach allows for:

1. **Incremental Development:** Build and test one component at a time
2. **Platform Flexibility:** Support Web, Desktop, and Android from day one
3. **Future iOS Support:** Architecture designed to add iOS later with minimal rework
4. **Cost Efficiency:** $0 development, $4/month production (excluding iOS)
5. **Testability:** Can test full multiplayer experience on single development machine

**Key Design Decisions:**
- **Dart server:** Same language as Flutter, enables code sharing
- **WebSocket:** Bidirectional, real-time, widely supported
- **Server-authoritative:** Prevents cheating, simplifies client code
- **Client-server (not P2P):** Better for turn-based games, easier to manage

**Timeline:**
- **MVP (Phases 1-5):** 5-7 weeks
- **Local Testing (Phase 6):** 1 week
- **Android Support (Phase 7):** 1-2 weeks
- **Production Deployment (Phase 8):** 1-2 weeks
- **Total:** 8-12 weeks for full implementation

**Next Steps:**
1. Review and approve this plan
2. Set up development environment (install Dart SDK for server)
3. Begin Phase 1: Server Foundation
4. Maintain regular testing throughout implementation

**For iOS Future:**
- Add 1-2 months after Android/Web/Desktop are stable
- Budget $99 for Apple Developer Account
- Use GitHub Actions to minimize CI/CD costs

This plan balances ambition with pragmatism, ensuring Chexx can support multiplayer while remaining maintainable and cost-effective.
