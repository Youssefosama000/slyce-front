import 'package:get/get.dart';
import 'package:slyce/core/network/api_exceptions.dart';
import 'package:slyce/features/onboarding/models/food_option_model.dart';
import 'package:slyce/features/onboarding/repositories/customer_repository.dart';

/// GetX controller for onboarding steps (gender, activity level, etc.).
class OnboardingController extends GetxController {
  final _customerRepo = CustomerRepository();

  // ── Observables ────────────────────────────────────────
  final isLoading = false.obs;
  final isLoadingOptions = false.obs;
  final errorMessage = ''.obs;

  // Onboarding data
  final selectedGender = ''.obs;
  final selectedActivityLevel = ''.obs;
  final weightKg = 70.8.obs;
  final heightCm = 170.0.obs;

  // Lookup options fetched from the API (carry the ids the API requires).
  final allergens = <FoodOptionModel>[].obs;
  final dietPreferences = <FoodOptionModel>[].obs;

  // Selected option *ids* (not names) – this is what the profile endpoints
  // expect.
  final selectedAllergies = <String>{}.obs;
  final selectedFoodPreferences = <String>{}.obs;

  // ── Update Gender ────────────────────────────────────────
  Future<void> updateGender() async {
    if (selectedGender.value.isEmpty) return;

    isLoading.value = true;
    errorMessage.value = '';

    try {
      await _customerRepo.updateGender(selectedGender.value);
      Get.toNamed('/weight');
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      // Still navigate even if API fails (data saved locally)
      Get.toNamed('/weight');
    } catch (_) {
      // Navigate anyway to not block user
      Get.toNamed('/weight');
    } finally {
      isLoading.value = false;
    }
  }

  // ── Update Weight ────────────────────────────────────────
  Future<void> updateWeight() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      await _customerRepo.updateWeight(weightKg.value);
      Get.toNamed('/height');
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      Get.toNamed('/height');
    } catch (_) {
      Get.toNamed('/height');
    } finally {
      isLoading.value = false;
    }
  }

  // ── Update Height ────────────────────────────────────────
  Future<void> updateHeight() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      await _customerRepo.updateHeight(heightCm.value);
      Get.toNamed('/activity');
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      Get.toNamed('/activity');
    } catch (_) {
      Get.toNamed('/activity');
    } finally {
      isLoading.value = false;
    }
  }

  // ── Update Activity Rate ──────────────────────────────────
  Future<void> updateActivityRate() async {
    if (selectedActivityLevel.value.isEmpty) return;

    isLoading.value = true;
    errorMessage.value = '';

    try {
      await _customerRepo.updateActivityRate(selectedActivityLevel.value);
      Get.toNamed('/allergies');
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      Get.toNamed('/allergies');
    } catch (_) {
      Get.toNamed('/allergies');
    } finally {
      isLoading.value = false;
    }
  }

  // ── Allergen / Preference lookups ─────────────────────────────
  /// Load the available allergens from the API (no-op if already loaded).
  Future<void> loadAllergens() async {
    if (allergens.isNotEmpty) return;
    isLoadingOptions.value = true;
    errorMessage.value = '';
    try {
      allergens.value = await _customerRepo.getAllergens();
    } on ApiException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      // Leave the list empty; the screen shows an empty state.
    } finally {
      isLoadingOptions.value = false;
    }
  }

  /// Load the available diet preferences from the API (no-op if already
  /// loaded).
  Future<void> loadDietPreferences() async {
    if (dietPreferences.isNotEmpty) return;
    isLoadingOptions.value = true;
    errorMessage.value = '';
    try {
      dietPreferences.value = await _customerRepo.getDietPreferences();
    } on ApiException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      // Leave the list empty; the screen shows an empty state.
    } finally {
      isLoadingOptions.value = false;
    }
  }

  void toggleAllergy(String id) {
    if (selectedAllergies.contains(id)) {
      selectedAllergies.remove(id);
    } else {
      selectedAllergies.add(id);
    }
  }

  void toggleFoodPreference(String id) {
    if (selectedFoodPreferences.contains(id)) {
      selectedFoodPreferences.remove(id);
    } else {
      selectedFoodPreferences.add(id);
    }
  }

  // ── Save Allergies ───────────────────────────────────────
  Future<void> saveAllergies() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      await _customerRepo.updateAllergens(selectedAllergies.toList());
      Get.toNamed('/food-preferences');
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      Get.toNamed('/food-preferences');
    } catch (_) {
      Get.toNamed('/food-preferences');
    } finally {
      isLoading.value = false;
    }
  }

  // ── Save Food Preferences ──────────────────────────────────
  Future<void> saveFoodPreferences() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      await _customerRepo
          .updateDietPreferences(selectedFoodPreferences.toList());
      Get.toNamed('/plan');
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      Get.toNamed('/plan');
    } catch (_) {
      Get.toNamed('/plan');
    } finally {
      isLoading.value = false;
    }
  }

  /// Activity rate names matching the backend enum values.
  // TODO: confirm — these are the exact enum values sent to the API. The
  // collection only documents "SuperActive"; 'ModeratlelyActive' (sic) is kept
  // verbatim per the existing code and must NOT be "corrected" unless the
  // backend enum actually changed.
  static const activityLevels = [
    'Sedentary',
    'LightlyActive',
    'ModeratlelyActive',
    'VeryActive',
    'SuperActive',
  ];
}
