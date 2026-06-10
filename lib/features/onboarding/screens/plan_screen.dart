import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/widgets/primary_button.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Progress
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: kCardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, size: 16, color: kDarkColor),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: const LinearProgressIndicator(
                        value: 1.0,
                        backgroundColor: kLightGrey,
                        valueColor: AlwaysStoppedAnimation<Color>(kPrimaryGreen),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '7/7',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: kGreyColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Icon pair
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _iconCircle(Icons.restaurant_menu_rounded, kPrimaryGreen),
                  const SizedBox(width: 20),
                  _iconCircle(Icons.fitness_center_rounded, kDarkGreen),
                ],
              ),
              const SizedBox(height: 40),
              Text(
                "Let's set up\nyour plan",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: kDarkColor,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Based on your profile, we\'ll build a personalized\nnutrition and activity plan just for you.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: kGreyColor,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Build My Plan',
                onTap: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (_) => false,
                ),
                color: kPrimaryGreen,
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconCircle(IconData icon, Color color) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: kWhite, size: 40),
    );
  }
}


