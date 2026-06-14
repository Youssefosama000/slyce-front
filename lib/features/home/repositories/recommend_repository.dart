import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:slyce/core/constants/ai_endpoints.dart';
import 'package:slyce/core/storage/secure_storage.dart';
import 'package:slyce/features/home/models/meal_model.dart';
import 'package:slyce/features/home/models/menu_item.dart';

/// Repository for the Slyce AI meal-recommendation endpoint (POST /recommend).
///
/// This endpoint lives on the same FastAPI service as the AI chat, so it uses
/// a dedicated Dio instance pointed at [AiEndpoints.baseUrl] (separate from the
/// main customer API).
class RecommendRepository {
  late final Dio _dio;

  /// Maps each recommended meal id to the restaurant id the recommender
  /// returned for it (response field `restaurant_id`). Repopulated on every
  /// [getRecommendations] call so the home controller can resolve the
  /// orderable branch from the meal's OWN restaurant — GET /meals/:id carries
  /// no restaurant/branch, so this hint is the most reliable owner source.
  final Map<String, String> lastRestaurantByMeal = <String, String>{};

  RecommendRepository() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        // Recommendations can take a few seconds to compute.
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }
  }

  /// Request personalised meal recommendations for [userId] using [profile].
  ///
  /// [profile] must match the API schema:
  /// { weight, height, age, gender, activity_level, goal, diet,
  ///   allergies: [...], diet_preferences: [...] }
  /// Returns the recommended meals mapped to the UI's [MenuItem] model.
  Future<List<MenuItem>> getRecommendations({
    required String userId,
    required Map<String, dynamic> profile,
    int topN = 10,
  }) async {
    // Attach the bearer token when present, in case the AI service is
    // protected. Harmless when the service is public.
    final token = await SecureStorage.instance.getAccessToken();
    final options = (token != null && token.isNotEmpty)
        ? Options(headers: {'Authorization': 'Bearer $token'})
        : null;

    final response = await _dio.post(
      AiEndpoints.recommend,
      // The service computes the user's nutrition targets server-side from
      // user_id; the request schema is just { user_id, top_n }.
      data: {
        'user_id': userId,
        'top_n': topN,
      },
      options: options,
    );

    return _parseMeals(response.data);
  }

  /// Map the recommended-meals payload into [MenuItem]s, tolerating the various
  /// shapes the service may return.
  List<MenuItem> _parseMeals(dynamic data) {
    final list = _extractList(data);
    lastRestaurantByMeal.clear();
    final meals = <MenuItem>[];
    for (final entry in list) {
      if (entry is! Map) continue;
      // Some recommenders wrap the meal under a `meal`/`item` key alongside a
      // score; fall back to the entry itself when there is no wrapper.
      final raw = (entry['meal'] is Map)
          ? entry['meal']
          : (entry['item'] is Map ? entry['item'] : entry);
      final mealMap = Map<String, dynamic>.from(raw as Map);
      // The recommender keys its rows by meal SIZE, so a row's own `id` /
      // `meal_size_id` is a MealSizeId — NOT the MealId. The detail screen
      // fetches GET /meals/:id with `item.id`, which must be the MealId, so
      // pin it from the real meal-id fields and strip the size id to stop
      // MealModel.fromJson from falling back to it.
      final mealId = _firstString(mealMap, const [
        'mealId',
        'meal_id',
        'mealID',
        'MealId',
        'MealID',
      ]);
      mealMap.remove('meal_size_id');
      mealMap.remove('mealSizeId');
      mealMap.remove('sizeId');
      mealMap.remove('size_id');
      if (mealId != null) {
        mealMap['mealId'] = mealId;
      } else {
        // No explicit meal id present: avoid mistaking a leftover size id for
        // it so we never open the detail screen with a MealSizeId.
        mealMap.remove('id');
      }
      // Capture the recommender's restaurant_id so the meal can be ordered
      // from its own restaurant's branch.
      final restaurantId = _firstString(mealMap, const [
        'restaurantId',
        'restaurant_id',
        'restaurantID',
        'RestaurantId',
      ]);
      if (restaurantId != null) {
        mealMap['restaurantId'] = restaurantId;
        if (mealId != null) {
          lastRestaurantByMeal[mealId] = restaurantId;
        }
      }
      meals.add(MealModel.fromJson(mealMap).toMenuItem());
    }
    return meals;
  }

  /// First non-empty string value among [keys] in [map].
  String? _firstString(Map map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  /// Unwrap the recommended-meals array from the common wrapper shapes
  /// (plain array, {recommendations:[]}, {data:[]}, {results:[]}, ...).
  List _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in const [
        'ranked_meals',
        'rankedMeals',
        'recommendations',
        'recommended',
        'meals',
        'results',
        'items',
        'data',
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
}
