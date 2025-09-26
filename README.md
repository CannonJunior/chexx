# CHEXX - Hexagonal Turn-Based Strategy Game

A strategic hexagonal board game built with Flutter and Flame engine, featuring tactical combat, time-based rewards, and meta-hexagon special abilities.

## 🎯 Game Overview

CHEXX is a turn-based strategy game played on a 61-hexagon board where two players battle for supremacy using unique unit types with special abilities.

### Key Features

- **61 hexagonal battlefield** with strategic positioning
- **3 unique major unit types** each with distinct abilities
- **6-second turn timer** with time-based reward system
- **Meta hexagons** that unlock special abilities
- **Configuration-driven design** with no hardcoded values
- **Cross-platform** support (Web, Android, iOS, Desktop)

## 🚀 Quick Start

### Option 1: Automated Setup (Recommended)

```bash
./start.sh
```

This script will:
- Install Flutter if needed and add it to PATH
- Set up dependencies
- Launch the game on your preferred platform

### Option 2: Setup Flutter PATH Only

If you already have Flutter installed but need to add it to PATH:

```bash
# Option A: Source the setup script (adds to current session)
source ./setup_flutter_path.sh

# Option B: Run the main script (auto-detects and configures)
./start.sh
```

### Option 3: Manual Setup

1. **Install Flutter** (if not already installed):
   ```bash
   # Download Flutter
   cd /tmp
   wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.3-stable.tar.xz
   tar xf flutter_linux_3.24.3-stable.tar.xz

   # Move to development directory
   mkdir -p ~/development
   mv flutter ~/development/

   # Add to PATH
   echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.bashrc
   source ~/.bashrc
   ```

2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the Game**:
   ```bash
   # Web (recommended for development)
   flutter run -d web-server --web-port=8888

   # Desktop Linux
   flutter config --enable-linux-desktop
   flutter run -d linux

   # Android (with device/emulator)
   flutter run -d android
   ```

## 🎮 How to Play

### Objective
Eliminate all enemy units to win the game.

### Unit Types

- **Minor Units (M)**: Basic units with 1 HP, short range attacks
- **Scout (S)**: Long-range attacks, fast movement in straight lines
- **Knight (K)**: High damage attacks, L-shaped movement patterns
- **Guardian (G)**: Defensive unit, can swap positions with allies

### Game Mechanics

1. **Turn System**: Each player has 6 seconds per turn
2. **Movement**: Tap your units to select, tap highlighted hexes to move
3. **Combat**: Tap enemy units within range to attack
4. **Meta Hexagons**: Purple hexes provide special abilities when occupied
5. **Rewards**: Faster decisions earn more reward points (0-61 scale)

### Controls

- **Tap units** to select them
- **Tap highlighted hexes** to move selected unit
- **Tap enemy units** to attack (if in range)
- **Use UI buttons** to end turn or pause game
- **Purple hexes** are Meta hexagons with special abilities

## 🏗️ Project Structure

```
lib/
├── main.dart                 # App entry point
├── src/
│   ├── components/          # Flame game components
│   │   ├── hex_tile_component.dart
│   │   ├── unit_component.dart
│   │   └── game_ui.dart
│   ├── models/             # Game data models
│   │   ├── hex_coordinate.dart
│   │   ├── game_unit.dart
│   │   ├── game_board.dart
│   │   └── game_state.dart
│   ├── screens/            # Flutter screens
│   │   └── game_screen.dart
│   └── systems/            # Core game systems
│       └── chexx_game.dart
assets/
├── config/                 # Game configuration
│   └── game_config.json
└── images/                # Game assets
```

## ⚙️ Configuration

Game parameters are stored in `assets/config/game_config.json`:

- **Board settings**: Hex count, size, Meta hex positions
- **Unit stats**: Health, movement, attack ranges
- **Gameplay**: Turn timer, reward multipliers
- **Balance**: Damage values, cooldowns

This design allows easy balance updates without code changes.

## 🔧 Development

### Architecture

- **Flutter + Flame**: Cross-platform game engine
- **Hexagonal coordinates**: Cube coordinate system for precise calculations
- **Component-based**: Modular game objects with clear separation
- **Configuration-driven**: External JSON files for all game data

### Key Design Decisions

1. **Cube Coordinates**: Provides symmetric hex math operations
2. **6-second turns**: Rewards quick tactical thinking
3. **Meta hexagons**: Create strategic position control points
4. **Phased implementation**: MVP → Core → Advanced features

### Running Tests

```bash
flutter test
```

### Building for Production

```bash
# Web
flutter build web --web-renderer canvaskit

# Android
flutter build apk

# Desktop Linux
flutter build linux
```

## 📋 Roadmap

### Phase 1: MVP ✅
- [x] Basic hex grid with movement
- [x] 3 Major Unit types
- [x] 6 Meta hexagons
- [x] Turn timer system
- [x] Configuration system

### Phase 2: Core Features (Planned)
- [ ] 5 Major Unit types (full roster)
- [ ] Complete Meta ability system
- [ ] Unit leveling mechanics
- [ ] Network multiplayer via Nakama
- [ ] Balance testing tools

### Phase 3: Advanced Features (Future)
- [ ] Super abilities system
- [ ] AI opponents
- [ ] Replay system
- [ ] Tournament mode
- [ ] Custom scenarios

## 🎨 Credits

- **Game Design**: Based on extensive research of tactical strategy games
- **Hex Grid Mathematics**: Inspired by Red Blob Games algorithms
- **Engine**: Built with Flutter and Flame
- **Architecture**: Configuration-driven, no hardcoded values

## 📄 License

This project is available for educational and development purposes.

---

**Have fun playing CHEXX! 🎯**

For support or questions, check the project documentation or create an issue.