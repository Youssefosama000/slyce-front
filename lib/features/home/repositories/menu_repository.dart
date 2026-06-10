import 'package:slyce/core/constants/api_endpoints.dart';
import 'package:slyce/core/network/dio_client.dart';
import 'package:slyce/features/home/models/meal_model.dart';
import 'package:slyce/features/home/models/restaurant.dart';

/// Repository for menu, meal and (read-only) restaurant API calls.
///
/// Customer scope only. The previous implementation loaded restaurants via the
/// ADMIN `restaurant-applications` endpoint, which is out of scope for the
/// customer app; it has been replaced with the customer
/// `GET /v1/restaurants/top-rated/nearby` endpoint.
class MenuRepository {
  final _client = DioClient.instance;

  /// Get the top-rated restaurants near a location.
  ///
  /// GET /v1/restaurants/top-rated/nearby with a `{ latitude, longitude }`
  /// JSON body, exactly as defined in the Postman collection (Slyce.json).
  Future<List<Restaurant>> getTopRatedRestaurantsNearby({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _client.get(
      ApiEndpoints.topRatedNearby,
      data: {
        'latitude': latitude,
        'longitude': longitude,
      },
    );
    return _extractList(response.data)
        .whereType<Map>()
        .map((e) => _restaurantFromJson(Map<String, dynamic>.from(e)))
        .where((r) => r.id.isNotEmpty)
        .toList();
  }

  /// Pull a list of records out of the various wrapper shapes the API may use
  /// (plain array, {data:[]}, {items:[]}, paginated {data:{items:[]}}, etc.).
  List _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in const [
        'items',
        'data',
        'restaurants',
        'results',
        'value',
      ]) {
        final v = data[key];
        if (v is List) return v;
        if (v is Map) {
          final nested = _extractList(v);
          if (nested.isNotEmpty) return nested;
        }
      }
    }
    return const [];
  }

  /// Map a restaurant payload to the UI's Restaurant model.
  Restaurant _restaurantFromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    final hoursList =
        data['workingHours'] ?? data['openingHours'] ?? [];

    return Restaurant(
      // The menu is per-restaurant, so the restaurant identity is the
      // `restaurantId`. Fall back to id/branchId only to keep the card
      // identifiable if a restaurantId is ever missing. The nearby branch's
      // `branchId` is captured separately as `defaultBranchId` for ordering.
      id: data['restaurantId']?.toString() ??
          data['id']?.toString() ??
          data['branchId']?.toString() ??
          '',
      name: data['restaurantName']?.toString() ??
          data['name']?.toString() ??
          'Restaurant',
      bannerUrl: data['restaurantBanner']?.toString() ??
          data['bannerUrl']?.toString() ??
          data['banner_url']?.toString() ??
          '',
      logoUrl: data['restaurantLogoUrl']?.toString() ??
          data['logoUrl']?.toString() ??
          data['logo_url']?.toString() ??
          '',
      location: data['location']?.toString() ??
          data['address']?.toString() ??
          '',
      phone: data['phone']?.toString() ??
          data['phoneNumber']?.toString() ??
          '',
      rating: _toDouble(data['rating']) ?? 0,
      openingHours: (hoursList as List)
          .map((h) => OpeningHours(
                day: h['day']?.toString() ?? '',
                open: h['open']?.toString() ??
                    h['openTime']?.toString() ??
                    '',
                close: h['close']?.toString() ??
                    h['closeTime']?.toString() ??
                    '',
              ))
          .toList(),
      categories: ((data['categories'] ?? []) as List)
          .map((e) => e.toString())
          .toList(),
      branches: _branchesFromJson(data),
      defaultBranchId: (data['defaultBranchId'] ??
              data['mainBranchId'] ??
              data['branchId'])
          ?.toString(),
      menu: const [],
    );
  }

  List<Branch> _branchesFromJson(Map<String, dynamic> data) {
    final raw = data['branches'] ?? data['branchList'] ?? [];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((b) => Branch.fromJson(Map<String, dynamic>.from(b)))
        .where((b) => b.id.isNotEmpty)
        .toList();
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// Get entire menu by restaurant ID.
  Future<MenuResponseModel> getMenu(String restaurantId) async {
    final response = await _client.get(
      ApiEndpoints.restaurantMenu(restaurantId),
    );
    if (response.data == null || response.data is! Map<String, dynamic>) {
      return const MenuResponseModel();
    }
    return MenuResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Fetch details for a single branch (GET /branches/:id/details).
  ///
  /// The response body only contains city/area/phoneNumber/workingHours — it
  /// has NO `id` and NO `restaurantId` — so we inject the id from the request
  /// path to keep the returned Branch identifiable.
  Future<Branch> getBranchDetails(String id) async {
    final response = await _client.get(ApiEndpoints.branchDetails(id));
    final data = response.data;
    final map = (data is Map<String, dynamic>)
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};
    map['id'] = map['id'] ?? map['branchId'] ?? id;
    return Branch.fromJson(map);
  }

  /// View a specific meal by ID.
  Future<MealModel> getMealById(String mealId) async {
    final response = await _client.get(ApiEndpoints.mealById(mealId));
    final data = response.data as Map<String, dynamic>;
    final mealData = data['data'] ?? data;
    return MealModel.fromJson(mealData as Map<String, dynamic>);
  }

  /// Search food with pagination.
  Future<List<MealModel>> searchFood({
    required String term,
    int pageSize = 20,
    int pageNumber = 1,
  }) async {
    final response = await _client.get(
      ApiEndpoints.foodSearch,
      queryParameters: {
        'term': term,
        'pageSize': pageSize,
        'pageNumber': pageNumber,
      },
    );
    final data = response.data;
    final items = (data is Map ? (data['data'] ?? data['items'] ?? []) : data) as List;
    return items
        .map((e) => MealModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Search food from external database.
  Future<List<MealModel>> searchExternalFood(String searchTerm) async {
    final response = await _client.post(
      ApiEndpoints.foodExternalSearch,
      queryParameters: {'searchterm': searchTerm},
    );
    final data = response.data;
    final items = (data is Map ? (data['data'] ?? data['items'] ?? []) : data) as List;
    return items
        .map((e) => MealModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
