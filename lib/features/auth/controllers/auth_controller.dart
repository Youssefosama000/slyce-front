import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slyce/core/network/api_exceptions.dart';
import 'package:slyce/core/storage/secure_storage.dart';
import 'package:slyce/features/auth/models/user_model.dart';
import 'package:slyce/features/auth/repositories/auth_repository.dart';
import 'package:slyce/widgets/app_snackbar.dart';

/// GetX controller for authentication (sign in, sign up, sign out).
class AuthController extends GetxController {
  final _authRepo = AuthRepository();
  final _storage = SecureStorage.instance;

  // ── Observables ─────────────────────────────────────────────────────
  final isLoading = false.obs;
  final errorMessage = ''.obs;
  final currentUser = Rxn<UserModel>();

  // ── Text controllers ────────────────────────────────────────────────
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final dayController = TextEditingController();
  final monthController = TextEditingController();
  final yearController = TextEditingController();
  final forgotEmailController = TextEditingController();

  /// Display text + selected value for the date-of-birth picker.
  final birthDateController = TextEditingController();
  DateTime? birthDate;



  // ── Sign In ─────────────────────────────────────────────────────────
  Future<void> signIn() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      errorMessage.value = 'Please enter your email and password.';
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      // Start every sign-in from a clean slate so a stale token/customerId
      // from a previous account can never leak into the new session.
      await _storage.clearAll();
      final user = await _authRepo.login(email: email, password: password);
      await _persistUser(user);
      currentUser.value = user;

      // Clear fields
      emailController.clear();
      passwordController.clear();

      // Navigate to home for existing users
      Get.offAllNamed('/home');
    } on ApiException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'An unexpected error occurred. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  // ── Sign Up ─────────────────────────────────────────────────────────
  Future<void> signUp() async {
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty || password.isEmpty) {
      errorMessage.value = 'Please fill in all required fields.';
      return;
    }

    if (password != confirmPassword) {
      errorMessage.value = 'Passwords do not match.';
      return;
    }

    // Build birthDay string from the selected date of birth (if any).
    String? birthDay;
    final dob = birthDate;
    if (dob != null) {
      birthDay =
          '${dob.year}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}';
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      // Clear any previous session so signing up with a new account never
      // silently resumes the previously logged-in account.
      await _storage.clearAll();
      final user = await _authRepo.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        phoneNumber: phoneController.text.trim().isEmpty
            ? null
            : phoneController.text.trim(),
        birthDay: birthDay,
      );
      await _persistUser(user);
      currentUser.value = user;

      // Clear fields
      firstNameController.clear();
      lastNameController.clear();
      emailController.clear();
      passwordController.clear();
      confirmPasswordController.clear();
      phoneController.clear();
      birthDateController.clear();
      birthDate = null;

      // Navigate to onboarding
      Get.offAllNamed('/gender');
    } on ApiException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'Registration failed. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  // ── Forgot Password ─────────────────────────────────────────────────
  Future<void> forgotPassword() async {
    final email = forgotEmailController.text.trim();
    if (email.isEmpty) {
      errorMessage.value = 'Please enter your email address.';
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      await _authRepo.forgotPassword(email: email);
      forgotEmailController.clear();
      showAppSnackbar(
        'Check your inbox for password reset instructions.',
        title: 'Email sent',
        type: AppSnackbarType.success,
      );
    } on ApiException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'Failed to send reset email. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  // ── Sign Out ────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _storage.clearAll();
    currentUser.value = null;
    Get.offAllNamed('/sign-in');
  }

  // ── Check existing session ──────────────────────────────────────────
  Future<bool> checkSession() async {
    final loggedIn = await _storage.isLoggedIn();
    if (loggedIn) {
      final name = await _storage.getUserName();
      final email = await _storage.getUserEmail();
      final id = await _storage.getCustomerId();
      currentUser.value = UserModel(
        id: id,
        firstName: name?.split(' ').first,
        lastName: name?.split(' ').length == 2 ? name!.split(' ').last : null,
        email: email,
      );
    }
    return loggedIn;
  }

  // ── Private ─────────────────────────────────────────────────────────
  Future<void> _persistUser(UserModel user) async {
    if (user.accessToken != null) {
      await _storage.setAccessToken(user.accessToken!);
    }
    if (user.refreshToken != null) {
      await _storage.setRefreshToken(user.refreshToken!);
    }
    if (user.id != null) {
      await _storage.setCustomerId(user.id!);
    }
    await _storage.setUserName(user.fullName);
    if (user.email != null) {
      await _storage.setUserEmail(user.email!);
    }
  }
}


