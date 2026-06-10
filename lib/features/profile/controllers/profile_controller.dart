import 'package:get/get.dart';
import 'package:slyce/core/network/api_exceptions.dart';
import 'package:slyce/features/auth/controllers/auth_controller.dart';
import 'package:slyce/features/profile/models/weight_entry_model.dart';
import 'package:slyce/features/profile/repositories/profile_repository.dart';

/// GetX controller for profile management and weight history.
class ProfileController extends GetxController {
  final _profileRepo = ProfileRepository();

  // ── Observables ─────────────────────────────────────────────────────
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = ''.obs;
  final weightHistory = <WeightEntryModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadWeightHistory();
  }

  /// Fetch and refresh the current user's profile.
  Future<void> loadProfile() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final user = await _profileRepo.getProfile();
      Get.find<AuthController>().currentUser.value = user;
    } on ApiException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'Failed to load profile.';
    } finally {
      isLoading.value = false;
    }
  }

  /// Update the current user's profile fields.
  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
  }) async {
    isSaving.value = true;
    errorMessage.value = '';

    try {
      final updated = await _profileRepo.updateProfile(
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
      );
      Get.find<AuthController>().currentUser.value = updated;
      return true;
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (_) {
      errorMessage.value = 'Failed to update profile.';
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /// Load weight history entries from API.
  Future<void> loadWeightHistory() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      weightHistory.value = await _profileRepo.getWeightHistory();
    } on ApiException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      // Empty history is valid for new users
      weightHistory.value = [];
    } finally {
      isLoading.value = false;
    }
  }

  /// Log a new weight entry and refresh the history.
  Future<bool> logWeight(double weightKg) async {
    isSaving.value = true;
    errorMessage.value = '';

    try {
      await _profileRepo.logWeight(weightKg);
      await loadWeightHistory();
      return true;
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (_) {
      errorMessage.value = 'Failed to log weight.';
      return false;
    } finally {
      isSaving.value = false;
    }
  }
}
