import 'package:get/get.dart';
import 'package:slyce/core/storage/secure_storage.dart';
import 'package:slyce/core/utils/jwt_utils.dart';
import 'package:slyce/features/onboarding/models/food_option_model.dart';
import 'package:slyce/features/onboarding/repositories/customer_repository.dart';

/// Controller for the "Account Info" screen under Settings.
///
/// It exposes two things:
///   1. The read-only identity claims embedded in the JWT access token
///      (sub, name, family_name, email, role, jti, exp, iss, aud).
///   2. The editable onboarding profile (gender, weight, height, activity
///      level, allergens, diet preferences) which is cached locally and
///      synced to the backend on [save].
class AccountInfoController extends GetxController {
  final _storage = SecureStorage.instance;
  final _repo = CustomerRepository();

  // ── Identity (read-only) ──────────────────────────────────────────
  final claims = <MapEntry<String, String>>[].obs;

  // ── Editable profile ──────────────────────────────────────────────
  final selectedGender = ''.obs;
  final selectedActivityLevel = ''.obs;
  final weightKg = 70.0.obs;
  final heightCm = 170.0.obs;

  final allergens = <FoodOptionModel>[].obs;
  final dietPreferences = <FoodOptionModel>[].obs;
  final selectedAllergies = <String>{}.obs;
  final selectedFoodPreferences = <String>{}.obs;

  // ── UI state ──────────────────────────────────────────────────────
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = ''.obs;

  static const List<String> genderOptions = ['Male', 'Female'];
  static const List<String> activityOptions = [
    'Sedentary',
    'LightlyActive',
    'ModeratlelyActive',
    'VeryActive',
    'SuperActive',
  ];

  @override
  void onInit() {
    super.onInit();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    isLoading.value = true;
    _loadClaims();
    // The local profile is instant (secure storage), so reveal the screen as
    // soon as it is ready instead of blocking on the network option lists.
    await _loadLocalProfile();
    isLoading.value = false;
    // Allergen / diet-preference options come from the API; load the master
    // lists first so chosen ids can be shown with their names, then pull the
    // authoritative saved profile from the backend.
    await _loadOptions();
    await _loadRemoteProfile();
  }

  // ── Selection handlers ────────────────────────────────────────────
  void setGender(String g) => selectedGender.value = g;

  void setActivityLevel(String a) => selectedActivityLevel.value = a;

  void changeWeight(double delta) {
    final next = (weightKg.value + delta).clamp(30.0, 300.0);
    weightKg.value = double.parse(next.toStringAsFixed(1));
  }

  void changeHeight(double delta) {
    final next = (heightCm.value + delta).clamp(100.0, 250.0);
    heightCm.value = next.toDouble();
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

  // ── Save ──────────────────────────────────────────────────────────
  /// Persists the profile locally first (so it survives even if the network
  /// call fails) and then pushes every field to the backend. Returns `true`
  /// only when the remote sync also succeeds.
  Future<bool> save() async {
    isSaving.value = true;
    errorMessage.value = '';

    // 1) Always cache locally so the data is never lost.
    if (selectedGender.value.isNotEmpty) {
      await _storage.setProfileGender(selectedGender.value);
    }
    if (selectedActivityLevel.value.isNotEmpty) {
      await _storage.setProfileActivityRate(selectedActivityLevel.value);
    }
    await _storage.setProfileWeightKg(weightKg.value);
    await _storage.setProfileHeightCm(heightCm.value);
    // Cache option *names* locally (the AI recommendation endpoint reads
    // names), while the backend sync below sends the option *ids*.
    await _storage
        .setProfileAllergies(_namesForSelected(selectedAllergies, allergens));
    await _storage.setProfileDietPreferences(
        _namesForSelected(selectedFoodPreferences, dietPreferences));

    // 2) Sync to the backend.
    try {
      if (selectedGender.value.isNotEmpty) {
        await _repo.updateGender(selectedGender.value);
      }
      if (selectedActivityLevel.value.isNotEmpty) {
        await _repo.updateActivityRate(selectedActivityLevel.value);
      }
      await _repo.updateWeight(weightKg.value);
      await _repo.updateHeight(heightCm.value);
      await _repo.updateAllergens(selectedAllergies.toList());
      await _repo.updateDietPreferences(selectedFoodPreferences.toList());
      return true;
    } catch (e) {
      errorMessage.value = 'Saved locally, but syncing to the server failed.';
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  // ── Loaders ───────────────────────────────────────────────────────
  void _loadClaims() {
    final list = <MapEntry<String, String>>[];
    _storage.getAccessToken().then((token) {
      if (token != null && token.isNotEmpty) {
        void add(String label, String? value) {
          if (value != null && value.isNotEmpty) {
            list.add(MapEntry(label, value));
          }
        }

        // Only the user-facing identity fields are shown: first name, last
        // name and email. The technical token claims (sub, role, jti, exp,
        // iss, aud) are intentionally omitted.
        add('First name', JwtUtils.givenName(token) ?? JwtUtils.name(token));
        add('Last name', JwtUtils.familyName(token));
        add('Email', JwtUtils.email(token));
      }
      claims.assignAll(list);
    });
  }

  Future<void> _loadLocalProfile() async {
    final g = await _storage.getProfileGender();
    if (g != null && g.isNotEmpty) selectedGender.value = g;

    final a = await _storage.getProfileActivityRate();
    if (a != null && a.isNotEmpty) selectedActivityLevel.value = a;

    final w = await _storage.getProfileWeightKg();
    if (w != null) weightKg.value = w;

    final h = await _storage.getProfileHeightCm();
    if (h != null) heightCm.value = h;

    selectedAllergies.assignAll(await _storage.getProfileAllergies());
    selectedFoodPreferences
        .assignAll(await _storage.getProfileDietPreferences());
  }

  Future<void> _loadOptions() async {
    try {
      final results = await Future.wait([
        _repo.getAllergens(),
        _repo.getDietPreferences(),
      ]);
      allergens.assignAll(results[0]);
      dietPreferences.assignAll(results[1]);
      // The locally cached profile stores option *names* (for the AI
      // recommendation endpoint), but the chips select by option *id*. Map
      // the saved names back to ids now that the options are loaded so the
      // previously chosen chips appear selected.
      selectedAllergies.assignAll(_idsForStored(selectedAllergies, allergens));
      selectedFoodPreferences
          .assignAll(_idsForStored(selectedFoodPreferences, dietPreferences));
    } catch (_) {
      // Options may be unavailable (e.g. offline); leave lists empty.
    }
  }

  /// Pull the authoritative saved profile from `GET /v1/customers/profile` and
  /// overlay it on top of the locally cached values. The backend returns the
  /// allergens and diet preferences as *ids*; the chips resolve those ids to
  /// their display names using the option lists loaded in [_loadOptions].
  Future<void> _loadRemoteProfile() async {
    try {
      final profile = await _repo.getProfile();

      if (profile.gender != null && profile.gender!.isNotEmpty) {
        selectedGender.value = profile.gender!;
      }
      if (profile.activityRate != null && profile.activityRate!.isNotEmpty) {
        selectedActivityLevel.value = profile.activityRate!;
      }
      if (profile.weightKg != null) weightKg.value = profile.weightKg!;
      if (profile.heightCm != null) heightCm.value = profile.heightCm!;

      if (profile.allergenIds.isNotEmpty) {
        selectedAllergies.assignAll(profile.allergenIds);
      }
      if (profile.dietPreferenceIds.isNotEmpty) {
        selectedFoodPreferences.assignAll(profile.dietPreferenceIds);
      }

      // Keep the local cache in sync with the authoritative names (the AI
      // recommendation endpoint reads names, not ids).
      await _storage
          .setProfileAllergies(_namesForSelected(selectedAllergies, allergens));
      await _storage.setProfileDietPreferences(
          _namesForSelected(selectedFoodPreferences, dietPreferences));
    } catch (_) {
      // Backend profile unavailable (e.g. offline) — keep the cached values.
    }
  }

  /// Convert stored values (which may be option names or ids) into option ids
  /// so the chips highlight correctly. Falls back to the raw value when no
  /// option matches.
  Set<String> _idsForStored(Set<String> stored, List<FoodOptionModel> options) {
    final result = <String>{};
    for (final value in stored) {
      FoodOptionModel? match;
      for (final o in options) {
        if (o.id == value || o.name.toLowerCase() == value.toLowerCase()) {
          match = o;
          break;
        }
      }
      result.add(match?.id ?? value);
    }
    return result;
  }

  /// Map selected option ids to their display names for local caching (the AI
  /// recommendation endpoint reads names). Falls back to the id when the name
  /// is unknown (e.g. options not loaded yet).
  List<String> _namesForSelected(
      Set<String> ids, List<FoodOptionModel> options) {
    final byId = {for (final o in options) o.id: o.name};
    return ids
        .map((id) => (byId[id]?.isNotEmpty ?? false) ? byId[id]! : id)
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
