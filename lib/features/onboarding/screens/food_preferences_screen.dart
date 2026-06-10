import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/features/onboarding/controllers/onboarding_controller.dart';
import 'package:slyce/widgets/onboarding_scaffold.dart';

class FoodPreferencesScreen extends StatefulWidget {
  const FoodPreferencesScreen({super.key});

  @override
  State<FoodPreferencesScreen> createState() => _FoodPreferencesScreenState();
}

class _FoodPreferencesScreenState extends State<FoodPreferencesScreen> {
  final OnboardingController controller = Get.find<OnboardingController>();

  @override
  void initState() {
    super.initState();
    controller.loadDietPreferences();
  }

  /// Best-effort icon for a given preference name.
  IconData _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('chicken') || n.contains('poultry')) {
      return Icons.set_meal_rounded;
    }
    if (n.contains('beef') || n.contains('meat')) {
      return Icons.lunch_dining_rounded;
    }
    if (n.contains('pork')) return Icons.kebab_dining_rounded;
    if (n.contains('seafood')) return Icons.water_rounded;
    if (n.contains('fish')) return Icons.phishing_rounded;
    if (n.contains('egg')) return Icons.egg_rounded;
    if (n.contains('vegetable') || n.contains('vegan') || n.contains('veg')) {
      return Icons.eco_rounded;
    }
    if (n.contains('fruit')) return Icons.apple_rounded;
    if (n.contains('grain')) return Icons.grain_rounded;
    if (n.contains('legume') || n.contains('bean')) return Icons.spa_rounded;
    if (n.contains('dairy') || n.contains('milk')) {
      return Icons.local_drink_rounded;
    }
    if (n.contains('nut') || n.contains('seed')) return Icons.park_rounded;
    return Icons.restaurant_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'What foods do you prefer?',
      subtitle: 'Select all that you enjoy eating',
      currentStep: 6,
      totalSteps: 7,
      onNext: () => controller.saveFoodPreferences(),
      child: Obx(() {
        if (controller.isLoadingOptions.value &&
            controller.dietPreferences.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimaryGreen),
          );
        }

        if (controller.dietPreferences.isEmpty) {
          return Center(
            child: Text(
              'No preference options available right now.',
              style: GoogleFonts.inter(fontSize: 14, color: kGreyColor),
            ),
          );
        }

        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
          ),
          itemCount: controller.dietPreferences.length,
          itemBuilder: (context, index) {
            final option = controller.dietPreferences[index];
            return Obx(() {
              final isSelected =
                  controller.selectedFoodPreferences.contains(option.id);
              return GestureDetector(
                onTap: () => controller.toggleFoodPreference(option.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? kPrimaryGreen : kCardColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _iconFor(option.name),
                        size: 20,
                        color: isSelected ? kWhite : kPrimaryGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          option.name,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? kWhite : kDarkColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            });
          },
        );
      }),
    );
  }
}
