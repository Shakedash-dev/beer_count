import 'package:beer_count/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('palette matches the spec exactly', () {
    expect(AppColors.bg, const Color(0xFF0B0B0C));
    expect(AppColors.surface, const Color(0xFF141416));
    expect(AppColors.surfaceAlt, const Color(0xFF1C1C1F));
    expect(AppColors.hairline, const Color(0xFF26262A));
    expect(AppColors.text, const Color(0xFFF4F1EA));
    expect(AppColors.textDim, const Color(0xFF8A8780));
    expect(AppColors.amber, const Color(0xFFE8A33D));
    expect(AppColors.amberDim, const Color(0xFF4A3A1E));
    expect(AppColors.over, const Color(0xFFD9603F));
  });

  test('theme is dark and uses amber as the only accent', () {
    final theme = buildTheme();
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppColors.bg);
    expect(theme.colorScheme.primary, AppColors.amber);
    expect(theme.colorScheme.secondary, AppColors.amber);
  });
}
