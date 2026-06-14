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
              const SizedBox(height: 24),
              Obx(() => AbsorbPointer(
                    absorbing: auth.isLoading.value,
                    child: PrimaryButton(
                      label: auth.isLoading.value ? 'Signing in...' : 'Login',
                      onTap: () => auth.signIn(),
                    ),
                  )),
              const SizedBox(height: 28),
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

}


