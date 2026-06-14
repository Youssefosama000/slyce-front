import 'package:get/get.dart';
import 'package:slyce/core/network/api_exceptions.dart';
import 'package:slyce/core/storage/secure_storage.dart';
import 'package:slyce/features/onboarding/models/food_option_model.dart';
import 'package:slyce/features/onboarding/repositories/customer_repository.dart';

/// Controller backing the editable "My Profile" screen.
///
/// Fields stay locked until [enableEditing] is called. Saving writes the
/// values to the customer profile API (PATCH /customers/me/profile/*) AND to
/// the local cache used to build the AI recommendation payload, so both stay
/// in sync.
class ProfileFormController extends GetxController {
  final _customerRepo = CustomerRepository();
  final _storage = SecureStorage.instance;

  // Valid activity-rate enum values accepted by the backend.
  static const activityOptions = <String>[
    'Sedentary',
    'LightlyActive',
    'ModeratlelyActive',
    'VeryActive',
    'SuperActive',
  ];
  static const genderOptions = <String>['Male', 'Female'];

  // ── Editable profile state ──────────────────────────────────────────
  final selectedGender = ''.obs;
  final selectedActivityLevel = ''.obs;
  final weightKg = 70.8.obs;
  final heightCm = 170.0.obs;

  final allergens = <FoodOptionModel>[].obs;
  final dietPreferences = <FoodOptionModel>[].obs;
  final selectedAllergies = <String>{}.obs;
  final selectedFoodPreferences = <String>{}.obs;

  // ── Status flags ────────────────────────────────────────────────────
  final isLoading = false.obs;
  final isSaving = false.obs;
  final isEditing = false.obs;
  final errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    isLoading.value = true;
    await _loadLocalProfile();
    await _loadOptions();
    isLoading.value = false;
  }

  /// Pre-fill editable fields from the locally cached profile values.
  Future<void> _loadLocalProfile() async {
    selectedGender.value = await _storage.getProfileGender() ?? '';
    selectedActivityLevel.value = await _storage.getProfileActivityRate() ?? '';
    weightKg.value = await _storage.getProfileWeightKg() ?? 70.8;
    heightCm.value = await _storage.getProfileHeightCm() ?? 170.0;
  }

  /// Load the allergen / diet-preference master lists, then derive the
  /// current selection from the cached profile.
  Future<void> _loadOptions() async {
    try {
      final results = await Future.wait([
        _customerRepo.getAllergens(),
        _customerRepo.getDietPreferences(),
      ]);
      allergens.assignAll(results[0]);
      dietPreferences.assignAll(results[1]);
    } catch (_) {
      // Lookup lists may be unavailable offline; leave them empty.
    }
    await _reselectFromCache();
  }

  /// Re-derive the selected option ids from the cached names (matched by
  /// name, case-insensitive).
  Future<void> _reselectFromCache() async {
    final cachedAllergyNames =
        (await _storage.getProfileAllergies()).map((e) => e.toLowerCase()).toSet();
    final cachedPrefNames = (await _storage.getProfileDietPreferences())
        .map((e) => e.toLowerCase())
        .toSet();

    selectedAllergies.assignAll(allergens
        .where((o) => cachedAllergyNames.contains(o.name.toLowerCase()))
        .map((o) => o.id));
    selectedFoodPreferences.assignAll(dietPreferences
        .where((o) => cachedPrefNames.contains(o.name.toLowerCase()))
        .map((o) => o.id));
  }

  // ── Edit mode ─────────────────────────────────────────────────────
  void enableEditing() {
    errorMessage.value = '';
    isEditing.value = true;
  }

  /// Discard any unsaved changes and lock the fields again.
  Future<void> cancelEditing() async {
    isLoading.value = true;
    await _loadLocalProfile();
    await _reselectFromCache();
    errorMessage.value = '';
    isEditing.value = false;
    isLoading.value = false;
  }

  // ── Editing helpers ─────────────────────────────────────────────────
  void setGender(String value) => selectedGender.value = value;

  void setActivityLevel(String value) => selectedActivityLevel.value = value;

  void changeWeight(double delta) {
    final next = (weightKg.value + delta).clamp(30.0, 300.0);
    weightKg.value = double.parse(next.toStringAsFixed(1));
  }

  void changeHeight(double delta) {
    final next = (heightCm.value + delta).clamp(100.0, 250.0);
    heightCm.value = double.parse(next.toStringAsFixed(0));
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

  List<String> _namesFor(List<FoodOptionModel> options, Set<String> ids) =>
      options.where((o) => ids.contains(o.id)).map((o) => o.name).toList();

  /// Persist edits locally first (so the AI payload is always up to date),
  /// then sync each field to the backend profile endpoints.
  Future<bool> save() async {
    isSaving.value = true;
    errorMessage.value = '';

    // 1) Local cache — always succeeds, keeps recommendations correct.
    await _storage.setProfileGender(selectedGender.value);
    await _storage.setProfileActivityRate(selectedActivityLevel.value);
    await _storage.setProfileWeightKg(weightKg.value);
    await _storage.setProfileHeightCm(heightCm.value);
    await _storage
        .setProfileAllergies(_namesFor(allergens, selectedAllergies));
    await _storage.setProfileDietPreferences(
        _namesFor(dietPreferences, selectedFoodPreferences));

    // 2) Backend sync via PATCH /customers/me/profile/*.
    try {
      if (selectedGender.value.isNotEmpty) {
        await _customerRepo.updateGender(selectedGender.value);
      }
      if (selectedActivityLevel.value.isNotEmpty) {
        await _customerRepo.updateActivityRate(selectedActivityLevel.value);
      }
      await _customerRepo.updateWeight(weightKg.value);
      await _customerRepo.updateHeight(heightCm.value);
      await _customerRepo.updateAllergens(selectedAllergies.toList());
      await _customerRepo.updateDietPreferences(
          selectedFoodPreferences.toList());
      isEditing.value = false;
      return true;
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      isEditing.value = false;
      return false;
    } catch (_) {
      errorMessage.value =
          'Saved on this device, but syncing with the server failed.';
      isEditing.value = false;
      return false;
    } finally {
      isSaving.value = false;
    }
  }
}
