import 'package:slyce/core/constants/api_endpoints.dart';
import 'package:slyce/core/network/dio_client.dart';
import 'package:slyce/features/onboarding/models/food_option_model.dart';
import 'package:slyce/features/profile/models/customer_profile_model.dart';

/// Repository for customer profile and onboarding API calls.
class CustomerRepository {
  final _client = DioClient.instance;

  /// Update the customer's gender during onboarding.
  Future<void> updateGender(String gender) async {
    await _client.patch(
      ApiEndpoints.updateGender,
      data: {'gender': gender},
    );
  }

  /// Update the customer's activity rate during onboarding.
  /// Valid values: Sedentary, LightlyActive, ModeratlelyActive, VeryActive,
  /// SuperActive
  Future<void> updateActivityRate(String activityRate) async {
    await _client.patch(
      ApiEndpoints.updateActivityRate,
      data: {'activityRate': activityRate},
    );
  }

  /// Update the customer's height during onboarding.
  Future<void> updateHeight(double heightCm) async {
    await _client.patch(
      ApiEndpoints.updateHeight,
      // The backend's UpdateHeightRequest expects an integer number of
      // centimetres. Sending a decimal (e.g. 180.0) fails JSON binding with a
      // 400 error, so round to the nearest whole cm before sending.
      data: {'heightCm': heightCm.round()},
    );
  }

  /// Update the customer's weight during onboarding.
  Future<void> updateWeight(double weightKg) async {
    await _client.patch(
      ApiEndpoints.updateWeight,
      data: {'weightKg': weightKg},
    );
  }

  /// Save the customer's selected allergens.
  ///
  /// The API expects allergen *ids* under `allergenIds`.
  Future<void> updateAllergens(List<String> allergenIds) async {
    await _client.patch(
      ApiEndpoints.updateAllergens,
      data: {'allergenIds': allergenIds},
    );
  }

  /// Save the customer's diet / food preferences.
  ///
  /// The API expects preference *ids* under `dietPreferenceIds`.
  Future<void> updateDietPreferences(List<String> dietPreferenceIds) async {
    await _client.patch(
      ApiEndpoints.updateDietPreferences,
      data: {'dietPreferenceIds': dietPreferenceIds},
    );
  }

  /// Fetch the master list of selectable allergens (id + name).
  Future<List<FoodOptionModel>> getAllergens() async {
    final response = await _client.get(ApiEndpoints.foodAllergens);
    return _parseOptions(response.data);
  }

  /// Fetch the master list of selectable diet / food preferences (id + name).
  Future<List<FoodOptionModel>> getDietPreferences() async {
    final response = await _client.get(ApiEndpoints.foodPreferences);
    return _parseOptions(response.data);
  }

  /// Fetch the saved customer profile (gender, weight, height, activity rate,
  /// and the chosen allergen / diet-preference *ids*) from
  /// `GET /v1/customers/profile`. The ids are resolved to names by the caller
  /// using the allergen / food-preference lookup lists.
  Future<CustomerProfileModel> getProfile() async {
    final response = await _client.get(ApiEndpoints.customerProfileGet);
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return CustomerProfileModel.fromJson(data);
    }
    if (data is Map) {
      return CustomerProfileModel.fromJson(Map<String, dynamic>.from(data));
    }
    return const CustomerProfileModel();
  }

  /// Normalises the various shapes the lookup endpoints may return into a
  /// flat list of options.
  List<FoodOptionModel> _parseOptions(dynamic data) {
    List items;
    if (data is List) {
      items = data;
    } else if (data is Map) {
      items = (data['data'] ?? data['items'] ?? data['results'] ?? []) as List;
    } else {
      items = [];
    }

    return items
        .whereType<Map>()
        .map((e) => FoodOptionModel.fromJson(Map<String, dynamic>.from(e)))
        .where((o) => o.id.isNotEmpty)
        .toList();
  }
}
