import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/features/auth/controllers/auth_controller.dart';
import 'package:slyce/widgets/custom_text_field.dart';
import 'package:slyce/widgets/primary_button.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

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
              const SizedBox(height: 72),
              // Logo
              Image.asset(
                'assets/images/logo.png',
                height: 110,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 64),
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
              CustomTextField(
                hint: 'Email or Phone Number',
                keyboardType: TextInputType.emailAddress,
                controller: auth.emailController,
                prefixIcon: Icons.mail_outline,
              ),
              const SizedBox(height: 14),
              CustomTextField(
                hint: 'Password',
                isPassword: true,
                controller: auth.passwordController,
                prefixIcon: Icons.lock_outline,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: Text(
                    'Forgot Password?',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: kGreyColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Obx(() => AbsorbPointer(
                    absorbing: auth.isLoading.value,
                    child: PrimaryButton(
                      label: auth.isLoading.value ? 'Signing in...' : 'Login',
                      onTap: () => auth.signIn(),
                    ),
                  )),
              const SizedBox(height: 28),
              _divider(),
              const SizedBox(height: 24),
              _googleButton(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: GoogleFonts.inter(fontSize: 14, color: kGreyColor),
                  ),
                  GestureDetector(
                    onTap: () => Get.toNamed('/sign-up'),
                    child: Text(
                      'Sign up',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: kPrimaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: kLightGrey)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or',
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
            _googleIcon(),
            const SizedBox(width: 10),
            Text(
              'Sign up with Google',
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

  Widget _googleIcon() {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Simple colored circle as Google icon placeholder
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


