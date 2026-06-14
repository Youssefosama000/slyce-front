import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/features/onboarding/models/food_option_model.dart';
import 'package:slyce/features/profile/controllers/account_info_controller.dart';

/// Single place under Settings that shows the signed-in account's identity
/// claims and lets the user edit their profile (gender, weight, height,
/// activity level, allergens and diet preferences).
class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  final controller = Get.put(AccountInfoController());

  @override
  void dispose() {
    Get.delete<AccountInfoController>();
    super.dispose();
  }

  Future<void> _onSave() async {
    await controller.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Saved changes',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor: kPrimaryGreen,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: kBgColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Account Info',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: kDarkColor,
          ),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimaryGreen),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            _sectionTitle('Identity'),
            _claimsCard(),
            const SizedBox(height: 24),
            _sectionTitle('Profile'),
            _genderField(),
            const SizedBox(height: 16),
            _stepperField(
              label: 'Weight',
              value: '${controller.weightKg.value.toStringAsFixed(1)} kg',
              onMinus: () => controller.changeWeight(-0.5),
              onPlus: () => controller.changeWeight(0.5),
            ),
            const SizedBox(height: 16),
            _stepperField(
              label: 'Height',
              value: '${controller.heightCm.value.toStringAsFixed(0)} cm',
              onMinus: () => controller.changeHeight(-1),
              onPlus: () => controller.changeHeight(1),
            ),
            const SizedBox(height: 16),
            _activityField(),
            const SizedBox(height: 16),
            _chipsField(
              label: 'Allergies',
              options: controller.allergens,
              selectedIds: controller.selectedAllergies,
              onToggle: controller.toggleAllergy,
            ),
            const SizedBox(height: 16),
            _chipsField(
              label: 'Diet Preferences',
              options: controller.dietPreferences,
              selectedIds: controller.selectedFoodPreferences,
              onToggle: controller.toggleFoodPreference,
            ),
            const SizedBox(height: 28),
            _saveButton(),
          ],
        );
      }),
    );
  }

  // ── Identity claims ─────────────────────────────────────────────
  Widget _claimsCard() {
    final claims = controller.claims;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLightGrey),
      ),
      child: claims.isEmpty
          ? Text(
              'No active session token found.',
              style: GoogleFonts.inter(fontSize: 13, color: kGreyColor),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < claims.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: kLightGrey),
                    ),
                  _claimRow(claims[i].key, claims[i].value),
                ],
              ],
            ),
    );
  }

  Widget _claimRow(String key, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: kGreyColor,
          ),
        ),
        const SizedBox(height: 2),
        SelectableText(
          value,
          style: GoogleFonts.robotoMono(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: kDarkColor,
          ),
        ),
      ],
    );
  }

  // ── Profile editors ────────────────────────────────────────────
  Widget _genderField() {
    return _fieldShell(
      label: 'Gender',
      child: Row(
        children: [
          for (final g in AccountInfoController.genderOptions) ...[
            Expanded(
              child: _selectablePill(
                label: g,
                selected: controller.selectedGender.value == g,
                onTap: () => controller.setGender(g),
              ),
            ),
            if (g != AccountInfoController.genderOptions.last)
              const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  Widget _activityField() {
    return _fieldShell(
      label: 'Activity Level',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final a in AccountInfoController.activityOptions)
            _selectableChip(
              label: a,
              selected: controller.selectedActivityLevel.value == a,
              onTap: () => controller.setActivityLevel(a),
            ),
        ],
      ),
    );
  }

  Widget _stepperField({
    required String label,
    required String value,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return _fieldShell(
      label: label,
      child: Row(
        children: [
          _roundButton(Icons.remove, onMinus),
          Expanded(
            child: Center(
              child: Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kDarkColor,
                ),
              ),
            ),
          ),
          _roundButton(Icons.add, onPlus),
        ],
      ),
    );
  }

  Widget _chipsField({
    required String label,
    required List<FoodOptionModel> options,
    required Set<String> selectedIds,
    required void Function(String id) onToggle,
  }) {
    return _fieldShell(
      label: label,
      child: options.isEmpty
          ? Text(
              'No options available.',
              style: GoogleFonts.inter(fontSize: 13, color: kGreyColor),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in options)
                  _selectableChip(
                    label: o.name,
                    selected: selectedIds.contains(o.id),
                    onTap: () => onToggle(o.id),
                  ),
              ],
            ),
    );
  }

  // ── Shared building blocks ──────────────────────────────────────
  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: kGreyColor,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _fieldShell({required String label, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLightGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kGreyColor,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _selectablePill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? kPrimaryGreen : kBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? kPrimaryGreen : kLightGrey,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : kDarkColor,
          ),
        ),
      ),
    );
  }

  Widget _selectableChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kPrimaryGreen : kBgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? kPrimaryGreen : kLightGrey,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : kDarkColor,
          ),
        ),
      ),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: kBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kLightGrey),
        ),
        child: Icon(icon, color: kDarkColor, size: 20),
      ),
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: controller.isSaving.value ? null : _onSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: controller.isSaving.value
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(
                'Save Changes',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
