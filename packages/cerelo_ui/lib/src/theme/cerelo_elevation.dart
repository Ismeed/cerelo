import 'package:flutter/material.dart';

/// Cerelo elevation tokens.
///
/// White cards sitting on the near-white the near-white page surface need depth to
/// read as distinct surfaces — a hairline border alone leaves them looking flat
/// and washed out. Shadows are tinted with the navy-black text color rather than
/// pure black, which keeps them from muddying the warm brand palette.
abstract final class CereloElevation {
  /// Resting surfaces: cards, list rows, tiles.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A101828), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x12101828), blurRadius: 6, offset: Offset(0, 2)),
  ];

  /// Interactive surfaces that need to lift off the page: sheets, menus.
  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x0F101828), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x1A101828), blurRadius: 16, offset: Offset(0, 8)),
  ];

  /// Sticky chrome: app bars and bottom navigation.
  static const List<BoxShadow> chrome = [
    BoxShadow(color: Color(0x0D101828), blurRadius: 12, offset: Offset(0, -2)),
  ];
}
