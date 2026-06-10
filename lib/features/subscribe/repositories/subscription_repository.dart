import 'package:slyce/core/constants/api_endpoints.dart';
import 'package:slyce/core/network/dio_client.dart';
import 'package:slyce/features/subscribe/models/subscription_model.dart';

/// Repository for subscription API calls.
///
/// Slyce.json exposes exactly two customer subscription endpoints:
///   POST /v1/subscriptions                       -> create a meal subscription
///   GET  /v1/subscriptions?Page=&PageSize=        -> customer subscriptions
class SubscriptionRepository {
  final _client = DioClient.instance;

  /// List the current customer's subscriptions (paged summary).
  Future<List<SubscriptionModel>> getSubscriptions({
    int page = 1,
    int pageSize = 10,
  }) async {
    final response = await _client.get(
      ApiEndpoints.subscriptions,
      queryParameters: {'Page': page, 'PageSize': pageSize},
    );
    final data = response.data;

    List items;
    if (data is List) {
      items = data;
    } else if (data is Map) {
      items = (data['subscriptions'] ??
          data['subscriptionsSummary'] ??
          data['items'] ??
          data['data'] ??
          data['results'] ??
          []) as List;
    } else {
      items = [];
    }

    return items
        .whereType<Map>()
        .map((e) => SubscriptionModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Create a new meal subscription.
  ///
  /// Body matches the `Subscribe To Restaurant Meals` request in Slyce.json:
  /// branchId, deliveryAddressId, timeSlot, deliveryDays, startDate,
  /// subscriptionMeals[{ MealSizeId, quantity }], billingCycle.
  Future<Map<String, dynamic>> subscribe({
    required String branchId,
    required String deliveryAddressId,
    required String timeSlot,
    required List<String> deliveryDays,
    required String startDate,
    required List<Map<String, dynamic>> subscriptionMeals,
    required String billingCycle,
  }) async {
    final response = await _client.post(
      ApiEndpoints.subscriptions,
      data: {
        'branchId': branchId,
        'deliveryAddressId': deliveryAddressId,
        'timeSlot': timeSlot,
        'deliveryDays': deliveryDays,
        'startDate': startDate,
        'subscriptionMeals': subscriptionMeals,
        'billingCycle': billingCycle,
      },
    );
    if (response.data == null || response.data is! Map<String, dynamic>) {
      return {'success': true};
    }
    return response.data as Map<String, dynamic>;
  }
}
