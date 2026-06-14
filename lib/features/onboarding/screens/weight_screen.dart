import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/features/onboarding/controllers/onboarding_controller.dart';
import 'package:slyce/widgets/onboarding_scaffold.dart';
import 'package:slyce/widgets/ruler_picker.dart';

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  double _weightKg = 70.8;
  bool _isKg = true;

  double get _displayValue => _isKg ? _weightKg : _weightKg * 2.20462;
  double get _min => _isKg ? 30.0 : 66.0;
  double get _max => _isKg ? 200.0 : 441.0;
  double get _step => _isKg ? 0.1 : 0.1;
  int get _decimals => _isKg ? 1 : 1;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'How Much Do You Weigh?',
      subtitle: 'We use this to calculate your daily needs',
      currentStep: 2,
      totalSteps: 7,
      onNext: () {
        final ctrl = Get.find<OnboardingController>();
        ctrl.weightKg.value = _weightKg;
        ctrl.updateWeight();
      },
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Unit toggle
          _unitToggle(),
          const SizedBox(height: 40),
          // Value display
          Text(
            _displayValue.toStringAsFixed(_decimals),
            style: GoogleFonts.inter(
              fontSize: 72,
              fontWeight: FontWeight.w800,
              color: kDarkColor,
              letterSpacing: -2,
            ),
          ),
          Text(
            _isKg ? 'kg' : 'lbs',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: kGreyColor,
            ),
          ),
          const SizedBox(height: 48),
          // Ruler
          RulerPicker(
            value: _displayValue,
            min: _min,
            max: _max,
            step: _step,
            decimalPlaces: _decimals,
            onChanged: (v) {
              setState(() {
                _weightKg = _isKg ? v : v / 2.20462;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _unitToggle() {
    return Container(
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleTab('KG', _isKg, () => setState(() => _isKg = true)),
          _toggleTab('LBS', !_isKg, () => setState(() => _isKg = false)),
        ],
      ),
    );
  }

  Widget _toggleTab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
        decoration: BoxDecoration(
          color: active ? kPrimaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: active ? kWhite : kGreyColor,
          ),
        ),
      ),
    );
  }
}


