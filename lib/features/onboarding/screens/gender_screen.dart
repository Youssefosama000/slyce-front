import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/features/onboarding/controllers/onboarding_controller.dart';
import 'package:slyce/widgets/onboarding_scaffold.dart';

class GenderScreen extends StatelessWidget {
  const GenderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<OnboardingController>();

    return OnboardingScaffold(
          title: 'Select Your Gender',
          subtitle: 'This helps us personalize your plan',
          currentStep: 1,
          totalSteps: 7,
          onNext: () {
            if (controller.selectedGender.value.isNotEmpty) {
              controller.updateGender();
            }
          },
          child: Row(
            children: [
              Expanded(child: _genderCard(controller, 'Male', Icons.male_rounded)),
              const SizedBox(width: 16),
              Expanded(child: _genderCard(controller, 'Female', Icons.female_rounded)),
            ],
          ),
        );
  }

  Widget _genderCard(OnboardingController controller, String label, IconData icon) {
    return Obx(() {
      final isSelected = controller.selectedGender.value == label;
      return GestureDetector(
        onTap: () => controller.selectedGender.value = label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 160,
          decoration: BoxDecoration(
            color: isSelected ? kPrimaryGreen : kCardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? kPrimaryGreen : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isSelected ? kWhite.withValues(alpha: 0.2) : kBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 36,
                  color: isSelected ? kWhite : kPrimaryGreen,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? kWhite : kDarkColor,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}


