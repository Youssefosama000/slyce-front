import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/features/auth/controllers/auth_controller.dart';
import 'package:slyce/widgets/custom_text_field.dart';
import 'package:slyce/widgets/primary_button.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              Text(
                'Create An Account',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: kDarkColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Let\'s get you started with Slyce — your solution to a healthy life.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: kGreyColor),
              ),
              const SizedBox(height: 28),
              // Error message
              Obx(() {
                if (auth.errorMessage.value.isEmpty) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    auth.errorMessage.value,
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.redAccent),
                  ),
                );
              }),
              // First Name & Last Name row
              Row(
                children: [
                  Expanded(child: CustomTextField(
                    hint: 'First Name',
                    controller: auth.firstNameController,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: CustomTextField(
                    hint: 'Last Name',
                    controller: auth.lastNameController,
                  )),
                ],
              ),
              const SizedBox(height: 14),
              CustomTextField(
                hint: 'Email',
                keyboardType: TextInputType.emailAddress,
                controller: auth.emailController,
              ),
              const SizedBox(height: 14),
              CustomTextField(
                hint: 'Phone Number',
                keyboardType: TextInputType.phone,
                controller: auth.phoneController,
              ),
              const SizedBox(height: 14),
              CustomTextField(
                hint: 'Password',
                isPassword: true,
                controller: auth.passwordController,
              ),
              const SizedBox(height: 14),
              CustomTextField(
                hint: 'Confirm Password',
                isPassword: true,
                controller: auth.confirmPasswordController,
              ),
              const SizedBox(height: 14),
              // Date of Birth picker
              _buildBirthDateField(context, auth),
              const SizedBox(height: 24),
              Obx(() => AbsorbPointer(
                    absorbing: auth.isLoading.value,
                    child: PrimaryButton(
                      label: auth.isLoading.value ? 'Creating account...' : 'Sign up',
                      onTap: () => auth.signUp(),
                    ),
                  )),
              const SizedBox(height: 24),
              _divider(),
              const SizedBox(height: 24),
              _googleButton(),
              const SizedBox(height: 24),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: GoogleFonts.inter(fontSize: 14, color: kGreyColor),
                    ),
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: Text(
                        'Sign in',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: kPrimaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBirthDateField(BuildContext context, AuthController auth) {
    return TextField(
      controller: auth.birthDateController,
      readOnly: true,
      style: const TextStyle(color: kDarkColor, fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Date of Birth',
        prefixIcon: Icon(Icons.cake_outlined, color: kGreyColor, size: 20),
        suffixIcon:
            Icon(Icons.calendar_today_rounded, color: kPrimaryGreen, size: 18),
      ),
      onTap: () => _pickBirthDate(context, auth),
    );
  }

  Future<void> _pickBirthDate(BuildContext context, AuthController auth) async {
    // Dismiss the keyboard in case another field was focused.
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final initial =
        auth.birthDate ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select your date of birth',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: kPrimaryGreen,
              onPrimary: kWhite,
              onSurface: kDarkColor,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: kPrimaryGreen),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      auth.birthDate = picked;
      auth.birthDateController.text =
          '${picked.day.toString().padLeft(2, '0')} / ${picked.month.toString().padLeft(2, '0')} / ${picked.year}';
    }
  }

  Widget _divider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: kLightGrey)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Or sign up with',
            style: GoogleFonts.inter(fontSize: 13, color: kGreyColor),
          ),
        ),
        const Expanded(child: Divider(color: kLightGrey)),
      ],
    );
  }

  Widget _googleButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: kLightGrey, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CustomPaint(painter: _GoogleLogoPainter()),
            ),
            const SizedBox(width: 10),
            Text(
              'Continue with Google',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: kDarkColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Simple colored circle as Google icon
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.57,
      3.14,
      true,
      paint,
    );
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.57,
      -3.14,
      true,
      paint,
    );
    // White center
    paint.color = kWhite;
    canvas.drawCircle(center, radius * 0.55, paint);
    // G letter placeholder dot
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - radius * 0.2, radius * 0.7, radius * 0.35),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
