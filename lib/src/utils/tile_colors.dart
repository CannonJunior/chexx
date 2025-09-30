import 'package:flutter/material.dart';
import '../models/game_board.dart';

class TileColors {
  static Color getColorForTileType(HexType type) {
    switch (type) {
      case HexType.normal:
        return Colors.lightGreen.shade100;
      case HexType.meta:
        return Colors.purple.shade200;
      case HexType.blocked:
        return Colors.grey.shade600;
      case HexType.ocean:
        return Colors.blue.shade300;
      case HexType.beach:
        return Colors.amber.shade200;
      case HexType.hill:
        return Colors.brown.shade300;
      case HexType.town:
        return Colors.grey.shade400;
      case HexType.forest:
        return Colors.green.shade600;
      case HexType.hedgerow:
        return Colors.green.shade800;
    }
  }

  static Color getButtonColorForTileType(HexType type) {
    switch (type) {
      case HexType.normal:
        return Colors.green.shade200;
      case HexType.meta:
        return Colors.purple.shade300;
      case HexType.blocked:
        return Colors.grey.shade600;
      case HexType.ocean:
        return Colors.blue.shade300;
      case HexType.beach:
        return Colors.amber.shade200;
      case HexType.hill:
        return Colors.brown.shade300;
      case HexType.town:
        return Colors.grey.shade400;
      case HexType.forest:
        return Colors.green.shade600;
      case HexType.hedgerow:
        return Colors.green.shade800;
    }
  }

  static Paint getPaintForTileType(HexType type) {
    return Paint()
      ..style = PaintingStyle.fill
      ..color = getColorForTileType(type);
  }
}