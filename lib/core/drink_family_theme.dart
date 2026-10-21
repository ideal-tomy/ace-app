import 'package:flutter/material.dart';

/// 注文画面のドリンクファミリチップ用の色（営業モード色とは別）。
class DrinkFamilyTheme {
  DrinkFamilyTheme._();

  static const _fallback = Color(0xFF64748B);

  static const Map<String, Color> _colors = {
    'sour': Color(0xFF0284C7),
    'tea_hai': Color(0xFF92400E),
    'soft': Color(0xFF059669),
    'beer': Color(0xFFD97706),
    'cocktail': Color(0xFFDB2777),
    'whisky': Color(0xFF7C3AED),
    'shochu': Color(0xFF4F46E5),
    'champagne': Color(0xFFCA8A04),
    'tequila': Color(0xFFEA580C),
    'others': Color(0xFF78716C),
    'bottle': Color(0xFF0F766E),
    'pitcher': Color(0xFF0369A1),
  };

  static Color colorForFamilyKey(String key) => _colors[key] ?? _fallback;
}
