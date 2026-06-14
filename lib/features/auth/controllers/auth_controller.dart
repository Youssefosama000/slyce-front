import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slyce/core/network/api_exceptions.dart';
import 'package:slyce/core/storage/secure_storage.dart';
import 'package:slyce/core/utils/jwt_utils.dart';
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

  @override
  void onInit() {
    super.onInit();
    // This controller is registered with fenix:true, so GetX can dispose and
    // recreate it during navigation, losing the in-memory user. Re-hydrate
    // from the stored session token (the same source the Account Info screen
    // uses) so the name shows on Home / Profile after navigation, hot restart,
    // or relaunching the app.
    if (currentUser.value == null) {
      checkSession();
    }
  }

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
      // Clear only the previous session (tokens/id). The cached onboarding
      // profile is preserved and reconciled below: a returning user keeps
      // their data, while a different account gets a clean profile.
      await _storage.clearSession();
      final user = await _authRepo.login(email: email, password: password);
      await _reconcileProfileOwner(user.id);
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
      // Clear any previous session so signing up never silently resumes the
      // previously logged-in account. The profile cache is reconciled by
      // owner below (a brand-new account id wipes any stale cached profile).
      await _storage.clearSession();
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
      await _reconcileProfileOwner(user.id);
      if (birthDay != null) {
        await _storage.setProfileBirthDay(birthDay);
      }
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
    // Keep the onboarding profile cache so the same user keeps their data
    // after logging back in; only the session/auth data is removed.
    await _storage.clearSession();
    currentUser.value = null;
    Get.offAllNamed('/sign-in');
  }

  // ── Check existing session ──────────────────────────────────────────
  Future<bool> checkSession() async {
    final token = await _storage.getAccessToken();
    if (token == null || token.isEmpty) {
      return _storage.isLoggedIn();
    }

    // Decode the identity straight from the JWT (the same source as the
    // Account Info screen) so the name / email / role are always consistent
    // across Home, Profile and Account Info.
    final id = JwtUtils.subject(token) ?? await _storage.getCustomerId();
    var firstName = JwtUtils.givenName(token);
    var lastName = JwtUtils.familyName(token);
    // The backend's token doesn't always carry name claims. Fall back to the
    // name we persisted at login so Home / Profile keep showing it after a
    // controller recreation, hot restart, or relaunch.
    if ((firstName == null || firstName.isEmpty) &&
        (lastName == null || lastName.isEmpty)) {
      final storedName = (await _storage.getUserName())?.trim();
      if (storedName != null && storedName.isNotEmpty && storedName != 'User') {
        firstName = storedName;
      }
    }
    currentUser.value = UserModel(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: JwtUtils.email(token) ?? await _storage.getUserEmail(),
      role: JwtUtils.role(token) ?? await _storage.getUserRole(),
      accessToken: token,
    );
    return true;
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
    if (user.role != null && user.role!.isNotEmpty) {
      await _storage.setUserRole(user.role!);
    }
  }

  /// Keeps a returning user's cached profile but wipes it when a *different*
  /// account signs in on this device. Records the current owner either way.
  Future<void> _reconcileProfileOwner(String? userId) async {
    if (userId == null || userId.isEmpty) return;
    final previousOwner = await _storage.getProfileOwnerId();
    if (previousOwner != null && previousOwner != userId) {
      await _storage.clearProfile();
    }
    await _storage.setProfileOwnerId(userId);
  }

  /// `true` when the signed-in user has the `Admin` role.
  bool get isAdmin => (currentUser.value?.role ?? '').toLowerCase() == 'admin';
}


