import 'package:slyce/core/constants/api_endpoints.dart';
import 'package:slyce/core/network/dio_client.dart';
import 'package:slyce/features/auth/models/user_model.dart';
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
}
