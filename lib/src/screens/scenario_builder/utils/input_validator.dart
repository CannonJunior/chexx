import 'dart:convert';

/// Security validation utilities for scenario builder input
class InputValidator {
  /// Maximum allowed file size for scenario JSON (10MB)
  static const int maxFileSizeBytes = 10 * 1024 * 1024;

  /// Maximum scenario name length
  static const int maxScenarioNameLength = 100;

  /// Minimum scenario name length
  static const int minScenarioNameLength = 1;

  /// Maximum win points value
  static const int maxWinPoints = 10000;

  /// Minimum win points value
  static const int minWinPoints = 1;

  /// Validate and sanitize scenario name
  /// Returns sanitized name or null if invalid
  static String? sanitizeScenarioName(String name) {
    if (name.isEmpty) {
      return null;
    }

    // Trim whitespace
    String sanitized = name.trim();

    // Check length
    if (sanitized.length < minScenarioNameLength ||
        sanitized.length > maxScenarioNameLength) {
      return null;
    }

    // Remove or replace dangerous characters
    // Allow: letters, numbers, spaces, hyphens, underscores, parentheses
    sanitized = sanitized.replaceAll(RegExp(r'[^\w\s\-\(\)]'), '');

    // Collapse multiple spaces
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');

    // Final trim
    sanitized = sanitized.trim();

    return sanitized.isEmpty ? null : sanitized;
  }

  /// Validate file size
  static bool isFileSizeValid(int sizeInBytes) {
    return sizeInBytes > 0 && sizeInBytes <= maxFileSizeBytes;
  }

  /// Validate JSON structure for scenario
  static ValidationResult validateScenarioJson(String jsonString) {
    // Check size first
    final bytes = utf8.encode(jsonString);
    if (!isFileSizeValid(bytes.length)) {
      return ValidationResult(
        isValid: false,
        error: 'File size exceeds maximum allowed size of ${maxFileSizeBytes ~/ (1024 * 1024)}MB',
      );
    }

    // Try to parse JSON
    Map<String, dynamic> data;
    try {
      final decoded = json.decode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        return ValidationResult(
          isValid: false,
          error: 'Invalid JSON structure: root must be an object',
        );
      }
      data = decoded;
    } catch (e) {
      return ValidationResult(
        isValid: false,
        error: 'Invalid JSON format: ${e.toString()}',
      );
    }

    // Validate required fields
    final requiredFields = ['name', 'board_config', 'placed_units'];
    for (final field in requiredFields) {
      if (!data.containsKey(field)) {
        return ValidationResult(
          isValid: false,
          error: 'Missing required field: $field',
        );
      }
    }

    // Validate scenario name
    if (data['name'] is! String) {
      return ValidationResult(
        isValid: false,
        error: 'Scenario name must be a string',
      );
    }

    final sanitizedName = sanitizeScenarioName(data['name'] as String);
    if (sanitizedName == null) {
      return ValidationResult(
        isValid: false,
        error: 'Invalid scenario name',
      );
    }

    // Validate board_config structure
    if (data['board_config'] is! Map) {
      return ValidationResult(
        isValid: false,
        error: 'board_config must be an object',
      );
    }

    // Validate placed_units is a list
    if (data['placed_units'] is! List) {
      return ValidationResult(
        isValid: false,
        error: 'placed_units must be an array',
      );
    }

    // Limit number of units (prevent DoS)
    final placedUnits = data['placed_units'] as List;
    if (placedUnits.length > 1000) {
      return ValidationResult(
        isValid: false,
        error: 'Too many units: maximum 1000 units allowed',
      );
    }

    // Validate win points if present
    if (data.containsKey('player1_win_points')) {
      final points = data['player1_win_points'];
      if (points is! int || !isWinPointsValid(points)) {
        return ValidationResult(
          isValid: false,
          error: 'Invalid player1_win_points value',
        );
      }
    }

    if (data.containsKey('player2_win_points')) {
      final points = data['player2_win_points'];
      if (points is! int || !isWinPointsValid(points)) {
        return ValidationResult(
          isValid: false,
          error: 'Invalid player2_win_points value',
        );
      }
    }

    return ValidationResult(isValid: true);
  }

  /// Validate win points value
  static bool isWinPointsValid(int points) {
    return points >= minWinPoints && points <= maxWinPoints;
  }

  /// Validate and clamp win points to valid range
  static int clampWinPoints(int points) {
    if (points < minWinPoints) return minWinPoints;
    if (points > maxWinPoints) return maxWinPoints;
    return points;
  }

  /// Get safe filename from scenario name
  static String getSafeFilename(String scenarioName) {
    final sanitized = sanitizeScenarioName(scenarioName);
    if (sanitized == null) {
      return 'scenario_${DateTime.now().millisecondsSinceEpoch}';
    }

    // Convert to lowercase and replace spaces with underscores
    String filename = sanitized.toLowerCase().replaceAll(' ', '_');

    // Remove any remaining non-alphanumeric characters except hyphens and underscores
    filename = filename.replaceAll(RegExp(r'[^a-z0-9\-_]'), '');

    // Ensure it's not empty
    if (filename.isEmpty) {
      return 'scenario_${DateTime.now().millisecondsSinceEpoch}';
    }

    return filename;
  }
}

/// Result of validation operation
class ValidationResult {
  final bool isValid;
  final String? error;

  ValidationResult({
    required this.isValid,
    this.error,
  });
}
