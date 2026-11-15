import 'package:flutter/material.dart';

/// The app's colours (docs/art.md 「顏色」): matt painted wood on a warm cream wall, words in a
/// deep walnut brown (never pure black).
abstract final class Wood {
  static const ink = Color(0xFF4A3426);
  static const inkSoft = Color(0xFF8A7464);
  static const wall = Color(0xFFF6EBDD);
  static const paper = Color(0xFFFFFAF2);
  static const light = Color(0xFFEBC995);
  static const mid = Color(0xFFD7A86E);
  static const dark = Color(0xFFA9773F);
  static const deep = Color(0xFF7A522B);
  static const hole = Color(0xFF8A5E33);
  static const red = Color(0xFFD9534A);
  static const orange = Color(0xFFF2994A);
  static const yellow = Color(0xFFF2C94C);
  static const green = Color(0xFF6FAE4E);
  static const teal = Color(0xFF2FA6A0);
  static const blue = Color(0xFF3F95D1);
  static const purple = Color(0xFF7B6CC8);
  static const pink = Color(0xFFEB7FA6);
  static const night1 = Color(0xFF2B2A4C);
  static const night2 = Color(0xFF5B4B7A);
  static const parentBg = Color(0xFFF4F1EC);
  static const line = Color(0xFFE3D2BC);
  static const glow = Color(0xFFFFE27A);

  /// The darker edge of a painted piece in [c].
  static Color edge(Color c) => Color.lerp(c, deep, .45)!;
}

abstract final class WoodTheme {
  /// jf open 粉圓 (OFL): a rounded typeface made in Taiwan.
  static const font = 'Huninn';

  static ThemeData light() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Wood.orange, surface: Wood.wall),
      scaffoldBackgroundColor: Wood.wall,
      fontFamily: font,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
    return base.copyWith(textTheme: base.textTheme.apply(bodyColor: Wood.ink, displayColor: Wood.ink, fontFamily: font));
  }
}
