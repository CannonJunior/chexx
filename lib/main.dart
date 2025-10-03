import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:html' as html;
import 'dart:convert';
import 'core/engine/game_plugin_manager.dart';
import 'games/chexx/chexx_plugin.dart';
import 'games/card/card_plugin.dart';
import 'src/screens/scenario_builder_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize plugin system
  final pluginManager = GamePluginManager();

  // Register CHEXX plugin
  final chexxPlugin = ChexxPlugin();
  await chexxPlugin.initialize();
  pluginManager.registerPlugin(chexxPlugin);

  // Register Card plugin
  final cardPlugin = CardPlugin();
  await cardPlugin.initialize();
  pluginManager.registerPlugin(cardPlugin);

  runApp(const TileGameFrameworkApp());
}

class TileGameFrameworkApp extends StatelessWidget {
  const TileGameFrameworkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tile-Based Game Framework',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: Brightness.dark,
      ),
      home: const MainMenuScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  String selectedGameMode = 'chexx'; // Default game mode
  Map<String, dynamic>? loadedScenario;
  String? scenarioName;
  String? errorMessage;
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.indigo.shade900,
              Colors.grey.shade900,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Game title
              const Spacer(),

              Text(
                'CHEXX',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 8.0,
                  shadows: [
                    Shadow(
                      offset: const Offset(2, 2),
                      blurRadius: 4,
                      color: Colors.black.withOpacity(0.7),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Hexagonal Turn-Based Strategy',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                  letterSpacing: 2.0,
                ),
              ),

              const Spacer(),

              // Game mode selection
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Select Game Mode:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Chexx mode
                    _buildGameModeOption(
                      'chexx',
                      'CHEXX',
                      'Classic hexagonal strategy game',
                      Colors.blue,
                    ),
                    const SizedBox(height: 12),

                    // WWII mode
                    _buildGameModeOption(
                      'wwii',
                      'WWII',
                      'World War II tactical combat (experimental)',
                      Colors.green,
                    ),
                    const SizedBox(height: 12),

                    // Card mode
                    _buildGameModeOption(
                      'card',
                      'Card Game',
                      'F-Card engine powered card gameplay',
                      Colors.purple,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Scenario loading section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Choose scenario file button
                      ElevatedButton.icon(
                        onPressed: isLoading ? null : _selectFile,
                        icon: const Icon(Icons.folder_open),
                        label: Text(isLoading ? 'Loading...' : 'Choose Scenario File'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Scenario status display
                      if (loadedScenario != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade900.withOpacity(0.3),
                            border: Border.all(color: Colors.green.shade600),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green.shade400, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Scenario Loaded Successfully!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Name: ${scenarioName ?? 'Custom Scenario'}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Units: ${(loadedScenario!['unit_placements'] as List?)?.length ?? 0}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Meta Hexes: ${(loadedScenario!['meta_hex_positions'] as List?)?.length ?? 0}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ] else if (errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade900.withOpacity(0.3),
                            border: Border.all(color: Colors.red.shade600),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.error, color: Colors.red.shade400, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Error Loading Scenario',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                errorMessage!,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade900.withOpacity(0.3),
                            border: Border.all(color: Colors.blue.shade600),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No scenario file selected',
                                style: TextStyle(color: Colors.white70),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Choose a .json file created by the Scenario Builder',
                                style: TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Action buttons
                      Row(
                        children: [
                          // Scenario Builder button
                          Expanded(
                            child: ElevatedButton(
                              onPressed: loadedScenario != null ? () => _openScenarioBuilderWithData(context) : () => _openScenarioBuilder(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'SCENARIO BUILDER',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Start Game button
                          Expanded(
                            child: ElevatedButton(
                              onPressed: loadedScenario != null ? () => _startGameWithScenario(context) : () => _startGameQuick(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: loadedScenario != null ? Colors.green.shade600 : Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'START GAME',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Instructions
              TextButton(
                onPressed: () => _showInstructions(context),
                child: const Text(
                  'How to Play',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameModeOption(String modeId, String title, String description, Color color) {
    final isSelected = selectedGameMode == modeId;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedGameMode = modeId;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.white24,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Selection indicator
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : Colors.white38,
                  width: 2,
                ),
                color: isSelected ? color : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // Mode info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      color: isSelected ? Colors.white70 : Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectFile() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final input = html.FileUploadInputElement()
        ..accept = '.json'
        ..click();

      await input.onChange.first;

      if (input.files!.isNotEmpty) {
        final file = input.files!.first;
        final reader = html.FileReader();
        reader.readAsText(file);

        await reader.onLoad.first;

        final content = reader.result as String;
        final Map<String, dynamic> scenario = json.decode(content);

        // Validate scenario structure
        _validateScenario(scenario);

        setState(() {
          loadedScenario = scenario;
          scenarioName = scenario['scenario_name'] as String?;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load scenario: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  void _validateScenario(Map<String, dynamic> scenario) {
    // Check required fields
    if (!scenario.containsKey('unit_placements')) {
      throw Exception('Missing unit_placements in scenario file');
    }
    if (!scenario.containsKey('meta_hex_positions')) {
      throw Exception('Missing meta_hex_positions in scenario file');
    }
    if (!scenario.containsKey('board')) {
      throw Exception('Missing board configuration in scenario file');
    }

    // Validate unit placements structure
    final unitPlacements = scenario['unit_placements'] as List;
    for (final placement in unitPlacements) {
      final placementMap = placement as Map<String, dynamic>;
      if (!placementMap.containsKey('template') || !placementMap.containsKey('position')) {
        throw Exception('Invalid unit placement structure');
      }
    }
  }

  void _startGameWithScenario(BuildContext context) {
    if (loadedScenario == null) return;

    // Inject the selected game mode into the scenario
    loadedScenario!['game_type'] = selectedGameMode;

    // Set landscape orientation for gameplay
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Use plugin system to start game with selected mode
    final pluginManager = GamePluginManager();
    final pluginId = selectedGameMode == 'card' ? 'card' : 'chexx';

    pluginManager.setActivePlugin(pluginId).then((_) {
      final plugin = pluginManager.getPlugin(pluginId);
      if (plugin != null) {
        final gameScreen = plugin.createGameScreen(scenarioConfig: loadedScenario);

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => gameScreen,
          ),
        ).then((_) {
          // Reset orientation when returning to menu
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        });
      }
    });
  }

  void _openScenarioBuilderWithData(BuildContext context) {
    // Set landscape orientation for better editing
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScenarioBuilderScreen(initialScenarioData: loadedScenario),
      ),
    ).then((_) {
      // Reset orientation when returning to menu
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    });
  }

  void _startGameQuick(BuildContext context) {
    // Set landscape orientation for better gameplay
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Create scenario config with selected game mode
    final scenarioConfig = {
      'game_type': selectedGameMode,
      'scenario_name': 'Quick Start ${selectedGameMode.toUpperCase()}',
      'unit_placements': [],
      'meta_hex_positions': [],
      'board': {'size': 5},
      'initial_hand_size': 5, // Configurable starting hand size for card game
    };

    // Use plugin system to start game with selected mode
    final pluginManager = GamePluginManager();
    final pluginId = selectedGameMode == 'card' ? 'card' : 'chexx';

    pluginManager.setActivePlugin(pluginId).then((_) {
      final plugin = pluginManager.getPlugin(pluginId);
      if (plugin != null) {
        final gameScreen = plugin.createGameScreen(scenarioConfig: scenarioConfig);

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => gameScreen,
          ),
        ).then((_) {
          // Reset orientation when returning to menu
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        });
      }
    });
  }

  void _openScenarioBuilder(BuildContext context) {
    // Set landscape orientation for better editing
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ScenarioBuilderScreen(),
      ),
    ).then((_) {
      // Reset orientation when returning to menu
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    });
  }

  void _showInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade800,
        title: const Text(
          'How to Play CHEXX',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInstructionItem(
                '1. Objective',
                'Eliminate all enemy units to win the game.',
              ),
              _buildInstructionItem(
                '2. Turn System',
                'Each turn lasts 6 seconds. Click/tap to move and attack.',
              ),
              _buildInstructionItem(
                '3. Unit Types',
                'Minor (M): Basic units with 1 HP\nScout (S): Long range attacks\nKnight (K): High damage but short range\nGuardian (G): Defensive unit',
              ),
              _buildInstructionItem(
                '4. Meta Hexagons',
                'Purple hexagons provide special abilities when occupied.',
              ),
              _buildInstructionItem(
                '5. Rewards',
                'Faster decisions earn more reward points (0-61).',
              ),
              _buildInstructionItem(
                '6. Controls',
                'Click your units to select, then click where to move or attack.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Got It!',
              style: TextStyle(color: Colors.blue.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}