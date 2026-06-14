import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';

/// Nutrition card shown on the meal detail screens.
///
/// Renders the meal's total calories and a per-macro breakdown as three rings.
/// Each ring shows that macro's share of the meal's calories, computed with the
/// standard Atwater factors:
///   - Protein: 4 kcal/g
///   - Carbs:   4 kcal/g
///   - Fats:    9 kcal/g
/// The percentages therefore reflect how the calories are actually split
/// between the macros (and always add up to 100%).
class NutritionInfoCard extends StatelessWidget {
  /// Total calories for the meal (already scaled by the selected quantity).
  final int calories;

  /// Macro grams (already scaled by the selected quantity).
  final double protein;
  final double fats;
  final double carbs;

  const NutritionInfoCard({
    super.key,
    required this.calories,
    required this.protein,
    required this.fats,
    required this.carbs,
  });

  // Macro colours (match the design).
  static const Color _proteinColor = Color(0xFFF5A623); // gold
  static const Color _fatsColor = Color(0xFFE53935); // red
  static const Color _carbsColor = Color(0xFFFF7043); // orange

  @override
  Widget build(BuildContext context) {
    // Calorie contribution of each macro (Atwater factors).
    final proteinKcal = protein * 4;
    final fatsKcal = fats * 9;
    final carbsKcal = carbs * 4;
    final totalMacroKcal = proteinKcal + fatsKcal + carbsKcal;

    double share(double macroKcal) =>
        totalMacroKcal <= 0 ? 0 : macroKcal / totalMacroKcal;

    return Column(
      children: [
        // Total calories header.
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$calories kcal',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: kDarkColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Total Calories',
              style: GoogleFonts.inter(fontSize: 12, color: kGreyColor),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Per-macro rings.
        Row(
          children: [
            Expanded(
              child: _MacroRing(
                label: 'Protein',
                grams: protein,
                percent: share(proteinKcal),
                color: _proteinColor,
              ),
            ),
            Expanded(
              child: _MacroRing(
                label: 'Fats',
                grams: fats,
                percent: share(fatsKcal),
                color: _fatsColor,
              ),
            ),
            Expanded(
              child: _MacroRing(
                label: 'Carbs',
                grams: carbs,
                percent: share(carbsKcal),
                color: _carbsColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MacroRing extends StatelessWidget {
  final String label;
  final double grams;
  final double percent; // 0..1 share of total calories
  final Color color;

  const _MacroRing({
    required this.label,
    required this.grams,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (percent * 100).round();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 84,
          height: 84,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: CircularProgressIndicator(
                  value: percent.clamp(0.0, 1.0),
                  strokeWidth: 7,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$pct%',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kDarkColor,
                    ),
                  ),
                  Text(
                    '${grams.round()}g',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kDarkColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: kGreyColor),
        ),
      ],
    );
  }
}
