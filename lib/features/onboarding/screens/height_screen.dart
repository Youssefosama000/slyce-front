import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/features/onboarding/controllers/onboarding_controller.dart';
import 'package:slyce/widgets/onboarding_scaffold.dart';
import 'package:slyce/widgets/ruler_picker.dart';

class HeightScreen extends StatefulWidget {
  const HeightScreen({super.key});

  @override
  State<HeightScreen> createState() => _HeightScreenState();
}

class _HeightScreenState extends State<HeightScreen> {
  double _heightCm = 165.0;
  bool _isCm = true;

  double get _displayValue => _isCm ? _heightCm : _heightCm / 30.48;
  double get _min => _isCm ? 100.0 : 3.0;
  double get _max => _isCm ? 250.0 : 8.2;
  double get _step => _isCm ? 1.0 : 0.1;
  int get _decimals => _isCm ? 0 : 1;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'How Tall Are You?',
      subtitle: 'Used to calculate your BMI and goals',
      currentStep: 3,
      totalSteps: 7,
      onNext: () {
        final ctrl = Get.find<OnboardingController>();
        ctrl.heightCm.value = _heightCm;
        ctrl.updateHeight();
      },
      child: Column(
        children: [
          const SizedBox(height: 20),
          _unitToggle(),
          const SizedBox(height: 40),
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
            _isCm ? 'cm' : 'ft',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: kGreyColor,
            ),
          ),
          const SizedBox(height: 48),
          RulerPicker(
            value: _displayValue,
            min: _min,
            max: _max,
            step: _step,
            decimalPlaces: _decimals,
            onChanged: (v) {
              setState(() {
                _heightCm = _isCm ? v : v * 30.48;
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
          _toggleTab('CM', _isCm, () => setState(() => _isCm = true)),
          _toggleTab('FT', !_isCm, () => setState(() => _isCm = false)),
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


