import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/features/onboarding/controllers/onboarding_controller.dart';
import 'package:slyce/widgets/onboarding_scaffold.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  static const _levels = [
    _ActivityLevel(
      label: 'Sedentary',
      apiValue: 'Sedentary',
      description: 'Little or no exercise',
      icon: Icons.chair_outlined,
    ),
    _ActivityLevel(
      label: 'Lightly Active',
      apiValue: 'LightlyActive',
      description: 'Light exercise 1-3 days/week',
      icon: Icons.directions_walk_rounded,
    ),
    _ActivityLevel(
      label: 'Moderately Active',
      apiValue: 'ModeratlelyActive',
      description: 'Moderate exercise 3-5 days/week',
      icon: Icons.directions_run_rounded,
    ),
    _ActivityLevel(
      label: 'Very Active',
      apiValue: 'VeryActive',
      description: 'Hard exercise 6-7 days/week',
      icon: Icons.fitness_center_rounded,
    ),
    _ActivityLevel(
      label: 'Super Active',
      apiValue: 'SuperActive',
      description: 'Very hard exercise & physical job',
      icon: Icons.sports_gymnastics_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<OnboardingController>();

    return OnboardingScaffold(
      title: 'How Active Are You?',
      subtitle: 'Select your typical activity level',
      currentStep: 4,
      totalSteps: 7,
      onNext: () => controller.updateActivityRate(),
      child: Obx(() {
            final selected = controller.selectedActivityLevel.value;
            return SingleChildScrollView(
              child: Column(
                children: _levels.map((level) {
                  final isSelected = selected == level.apiValue;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () => controller.selectedActivityLevel.value = level.apiValue,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected ? kPrimaryGreen : kCardColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? kWhite.withValues(alpha: 0.2)
                                    : kBgColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                level.icon,
                                size: 22,
                                color: isSelected ? kWhite : kPrimaryGreen,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    level.label,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? kWhite : kDarkColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    level.description,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: isSelected
                                          ? kWhite.withValues(alpha: 0.8)
                                          : kGreyColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: isSelected ? kWhite : kGreyColor,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }),
    );
  }
}

class _ActivityLevel {
  final String label;
  final String apiValue;
  final String description;
  final IconData icon;

  const _ActivityLevel({
    required this.label,
    required this.apiValue,
    required this.description,
    required this.icon,
  });
}


