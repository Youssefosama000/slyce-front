import 'package:slyce/core/constants/api_endpoints.dart';
import 'package:slyce/core/network/dio_client.dart';
import 'package:slyce/core/storage/secure_storage.dart';
import 'package:slyce/features/auth/models/user_model.dart';
import 'package:slyce/features/profile/models/customer_profile_model.dart';
import 'package:slyce/features/profile/models/weight_entry_model.dart';

/// Repository for customer profile and weight history API calls.
class ProfileRepository {
  final _client = DioClient.instance;

  /// Fetch the current customer's full profile.
  Future<UserModel> getProfile() async {
    final response = await _client.get(ApiEndpoints.customerProfile);
    if (response.data == null || response.data is! Map<String, dynamic>) {
      return const UserModel();
    }
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Update the customer's profile fields.
  Future<UserModel> updateProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
  }) async {
    final response = await _client.patch(
      ApiEndpoints.customerProfile,
      data: {
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
      },
    );
    if (response.data == null || response.data is! Map<String, dynamic>) {
      return UserModel(
          firstName: firstName,
          lastName: lastName,
          phoneNumber: phoneNumber);
    }
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Retrieve the customer's weight log history.
  Future<List<WeightEntryModel>> getWeightHistory() async {
    final response = await _client.get(ApiEndpoints.weightHistory);
    final data = response.data;

    List items;
    if (data is List) {
      items = data;
    } else if (data is Map) {
      items = (data['data'] ?? data['entries'] ?? []) as List;
    } else {
      items = [];
    }

    return items
        .map((e) => WeightEntryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Log a new weight entry.
  Future<void> logWeight(double weightKg) async {
    await _client.post(
      ApiEndpoints.weightHistory,
      data: {'weightKg': weightKg},
    );
  }

  /// Build the AI profile payload shared by POST /recommend and POST /chat.
  ///
  /// Sourced from the onboarding data persisted locally (the customer API has
  /// no profile-read endpoint for these fields) plus the latest logged weight.
  /// Matches the API schema:
  /// { weight, height, age, gender, activity_level, goal, diet,
  ///   allergies: [...], diet_preferences: [...] }.
  Future<Map<String, dynamic>> buildAiProfile() async {
    final store = SecureStorage.instance;

    // Authoritative profile from the server (gender, weightKg, heightCm,
    // activityRate, allergen ids, diet-preference ids). Falls back to the
    // locally cached onboarding values when the request fails.
    CustomerProfileModel? remote;
    try {
      final response = await _client.get(ApiEndpoints.customerProfileGet);
      final data = response.data;
      if (data is Map) {
        remote = CustomerProfileModel.fromJson(
          Map<String, dynamic>.from(data),
        );
      }
    } catch (_) {
      // Server profile is optional — fall back to local values below.
    }

    // Weight: most recent logged entry > server profile > local onboarding.
    double weight = 0;
    try {
      final history = await getWeightHistory();
      if (history.isNotEmpty) {
        history.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
        weight = history.first.weightKg;
      }
    } catch (_) {
      // Weight history is optional — proceed without it.
    }
    if (weight == 0) weight = remote?.weightKg ?? 0;
    if (weight == 0) weight = await store.getProfileWeightKg() ?? 0;

    final height = remote?.heightCm ?? await store.getProfileHeightCm() ?? 0;
    final gender = (remote != null &&
            remote.gender != null &&
            remote.gender!.isNotEmpty)
        ? remote.gender!
        : (await store.getProfileGender() ?? '');
    final activity = (remote != null &&
            remote.activityRate != null &&
            remote.activityRate!.isNotEmpty)
        ? remote.activityRate!
        : (await store.getProfileActivityRate() ?? '');
    final birthDay = await store.getProfileBirthDay();
    final allergies = (remote != null && remote.allergenIds.isNotEmpty)
        ? remote.allergenIds
        : await store.getProfileAllergies();
    final dietPrefs = (remote != null && remote.dietPreferenceIds.isNotEmpty)
        ? remote.dietPreferenceIds
        : await store.getProfileDietPreferences();

    return <String, dynamic>{
      'weight': weight,
      'height': height,
      'age': _ageFromBirthday(birthDay),
      'gender': gender,
      'activity_level': activity,
      'goal': '',
      'diet': '',
      'allergies': allergies,
      'diet_preferences': dietPrefs,
    };
  }

  /// Whole-years age from an ISO birthday string; 0 when unknown/invalid.
  int _ageFromBirthday(String? birthDay) {
    if (birthDay == null || birthDay.isEmpty) return 0;
    final dob = DateTime.tryParse(birthDay);
    if (dob == null) return 0;
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }
}
