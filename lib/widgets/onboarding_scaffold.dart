import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/widgets/primary_button.dart';

class OnboardingScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int currentStep;
  final int totalSteps;
  final Widget child;
  final VoidCallback onNext;
  final String nextLabel;

  const OnboardingScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.currentStep,
    required this.totalSteps,
    required this.child,
    required this.onNext,
    this.nextLabel = 'Next',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Progress bar + back
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
                      child: LinearProgressIndicator(
                        value: currentStep / totalSteps,
                        backgroundColor: kLightGrey,
                        valueColor: const AlwaysStoppedAnimation<Color>(kPrimaryGreen),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '$currentStep/$totalSteps',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: kGreyColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: kDarkColor,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: kGreyColor,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Expanded(child: child),
              const SizedBox(height: 16),
              PrimaryButton(
                label: nextLabel,
                onTap: onNext,
                color: kPrimaryGreen,
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}


