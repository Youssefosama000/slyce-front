import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/features/onboarding/controllers/onboarding_controller.dart';
import 'package:slyce/widgets/onboarding_scaffold.dart';

class AllergiesScreen extends StatefulWidget {
  const AllergiesScreen({super.key});

  @override
  State<AllergiesScreen> createState() => _AllergiesScreenState();
}

class _AllergiesScreenState extends State<AllergiesScreen> {
  final OnboardingController controller = Get.find<OnboardingController>();

  @override
  void initState() {
    super.initState();
    controller.loadAllergens();
  }

  /// Best-effort icon for a given allergen name.
  IconData _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('gluten') || n.contains('wheat')) return Icons.grain_rounded;
    if (n.contains('dairy') || n.contains('milk') || n.contains('lactose')) {
      return Icons.local_drink_outlined;
    }
    if (n.contains('egg')) return Icons.egg_outlined;
    if (n.contains('peanut')) return Icons.spa_outlined;
    if (n.contains('nut')) return Icons.park_outlined;
    if (n.contains('shell') || n.contains('crab') || n.contains('shrimp')) {
      return Icons.set_meal_outlined;
    }
    if (n.contains('soy')) return Icons.grass_outlined;
    if (n.contains('fish')) return Icons.phishing_outlined;
    if (n.contains('sesame')) return Icons.circle_outlined;
    return Icons.warning_amber_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Do you have any allergies?',
      subtitle: 'Select all that apply',
      currentStep: 5,
      totalSteps: 7,
      onNext: () => controller.saveAllergies(),
      child: Obx(() {
        if (controller.isLoadingOptions.value && controller.allergens.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimaryGreen),
          );
        }

        if (controller.allergens.isEmpty) {
          return Center(
            child: Text(
              'No allergen options available right now.',
              style: GoogleFonts.inter(fontSize: 14, color: kGreyColor),
            ),
          );
        }

        return ListView.separated(
          itemCount: controller.allergens.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final option = controller.allergens[index];
            return Obx(() {
              final isSelected =
                  controller.selectedAllergies.contains(option.id);
              return GestureDetector(
                onTap: () => controller.toggleAllergy(option.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? kPrimaryGreen : kCardColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _iconFor(option.name),
                        size: 22,
                        color: isSelected ? kWhite : kPrimaryGreen,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          option.name,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? kWhite : kDarkColor,
                          ),
                        ),
                      ),
                      Icon(
                        isSelected
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        color: isSelected ? kWhite : kGreyColor,
                        size: 22,
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
