import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:html' as html;
import 'dart:convert';
import 'core/engine/game_plugin_manager.dart';
import 'games/chexx/chexx_plugin.dart';
import 'src/screens/scenario_builder_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize plugin system
  final pluginManager = GamePluginManager();
  final chexxPlugin = ChexxPlugin();
  await chexxPlugin.initialize();
  pluginManager.registerPlugin(chexxPlugin);

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

              // Game info
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
                      'Game Features:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildFeatureItem('✅ 61 hexagonal battlefield'),
                    _buildFeatureItem('✅ 3 unique major unit types'),
                    _buildFeatureItem('✅ 6-second turn timer'),
                    _buildFeatureItem('✅ Meta hexagon special abilities'),
                    _buildFeatureItem('✅ Strategic positioning gameplay'),
                    _buildFeatureItem('✅ Custom Flutter game engine'),
                  ],
                ),
              ),

              const Spacer(),

              // Play button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => _startGame(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 8,
                    ),
                    child: const Text(
                      'START GAME',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Button row for Scenario Builder and Load Scenario
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  children: [
                    // Scenario Builder button
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => _openScenarioBuilder(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          child: const Text(
                            'SCENARIO\nBUILDER',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Load Scenario button
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => _loadScenario(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          child: const Text(
                            'LOAD\nSCENARIO',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.hexagon,
            color: Colors.blue.shade400,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startGame(BuildContext context) {
    // Set landscape orientation for better gameplay
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Use plugin system to start CHEXX game
    final pluginManager = GamePluginManager();
    pluginManager.setActivePlugin('chexx').then((_) {
      final gameScreen = pluginManager.createGameScreen();

      if (gameScreen != null) {
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

  void _loadScenario(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ScenarioLoaderDialog(),
    );
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

/// Dialog for loading scenario files
class ScenarioLoaderDialog extends StatefulWidget {
  const ScenarioLoaderDialog({super.key});

  @override
  State<ScenarioLoaderDialog> createState() => _ScenarioLoaderDialogState();
}

class _ScenarioLoaderDialogState extends State<ScenarioLoaderDialog> {
  Map<String, dynamic>? loadedScenario;
  String? scenarioName;
  String? errorMessage;
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey.shade800,
      title: const Text(
        'Load Custom Scenario',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select a scenario file created with the Scenario Builder:',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),

            // File selection button
            Center(
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : _selectFile,
                icon: const Icon(Icons.folder_open),
                label: Text(isLoading ? 'Loading...' : 'Choose Scenario File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Scenario info display
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ),
        ElevatedButton(
          onPressed: loadedScenario != null ? () => _openScenarioBuilderWithData(context) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
          ),
          child: const Text('Scenario Builder'),
        ),
        ElevatedButton(
          onPressed: loadedScenario != null ? () => _startGameWithScenario(context) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
          ),
          child: const Text('Start Game'),
        ),
      ],
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

    // Set landscape orientation for gameplay
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    Navigator.of(context).pop(); // Close dialog
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          // Create CHEXX plugin instance for the game screen
          final plugin = ChexxPlugin();
          return plugin.createGameScreen(scenarioConfig: loadedScenario);
        },
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

  void _openScenarioBuilderWithData(BuildContext context) {
    // Close the dialog first
    Navigator.of(context).pop();

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
}