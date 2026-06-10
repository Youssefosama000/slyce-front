// Models for menu/meal API responses, designed to be
// compatible with the existing MenuItem model used in UI.
import 'package:slyce/features/home/models/menu_item.dart';
import 'package:slyce/features/home/models/restaurant.dart';

// ── Size Model ──────────────────────────────────────────────────────────
class MealSizeModel {
  final String? id;
  final String name;
  final double price;
  final int sortOrder;
  // GET /meals/:id nests nutrition and ingredients INSIDE each size, so every
  // size carries its own macros and ingredient list.
  final NutritionInfo nutrition;
  final List<IngredientModel> ingredients;

  const MealSizeModel({
    this.id,
    required this.name,
    required this.price,
    this.sortOrder = 0,
    this.nutrition =
        const NutritionInfo(calories: 0, protein: 0, fats: 0, carbs: 0),
    this.ingredients = const [],
  });

  factory MealSizeModel.fromJson(Map<String, dynamic> json) {
    final nut = json['nutrition'] is Map
        ? Map<String, dynamic>.from(json['nutrition'] as Map)
        : const <String, dynamic>{};
    final ingList = json['ingredients'] ?? json['mealIngredients'] ?? const [];
    return MealSizeModel(
      id: json['sizeId']?.toString() ?? json['id']?.toString(),
      name: json['sizeName']?.toString() ?? json['name']?.toString() ?? 'Regular',
      price: _toDouble(json['price']),
      sortOrder: _toInt(json['sortOrder']),
      nutrition: NutritionInfo(
        calories: _toDouble(nut['calories']).toInt(),
        protein: _toDouble(nut['protein']),
        fats: _toDouble(nut['totalFat'] ?? nut['fats'] ?? nut['fat']),
        carbs: _toDouble(
            nut['totalCarbohydrate'] ?? nut['carbs'] ?? nut['carbohydrate']),
      ),
      ingredients: (ingList is List)
          ? ingList
              .map((e) => e is Map<String, dynamic>
                  ? IngredientModel.fromJson(e)
                  : IngredientModel(name: e.toString()))
              .toList()
          : const [],
    );
  }

  static double _toDouble(dynamic v) =>
      v is double ? v : (v is int ? v.toDouble() : double.tryParse('$v') ?? 0);
  static int _toInt(dynamic v) =>
      v is int ? v : (v is double ? v.toInt() : int.tryParse('$v') ?? 0);
}

// ── Ingredient Model ────────────────────────────────────────────────────
class IngredientModel {
  final String? id;
  final String name;
  final String? quantity;

  const IngredientModel({this.id, required this.name, this.quantity});

  factory IngredientModel.fromJson(Map<String, dynamic> json) {
    return IngredientModel(
      id: json['id']?.toString(),
      name: json['ingredientName']?.toString() ??
          json['name']?.toString() ??
          'Unknown',
      quantity:
          _formatQty(json['qty'] ?? json['quantity'] ?? json['amount']),
    );
  }

  /// Ingredient weights come back as numbers like 200.0; show them as a clean
  /// gram value ("200g", "40.44g") instead of "200.0".
  static String? _formatQty(dynamic v) {
    if (v == null) return null;
    final n = v is num ? v : num.tryParse(v.toString());
    if (n == null) {
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }
    final num val = n == n.roundToDouble() ? n.round() : n;
    return '${val}g';
  }

  Ingredient toIngredient() => Ingredient(
        name: name,
        amount: quantity ?? '',
      );
}

// ── Meal (API response) ─────────────────────────────────────────────────
class MealModel {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? categoryId;
  final String? categoryName;
  final List<MealSizeModel> sizes;
  final List<IngredientModel> ingredients;
  /// Flat price used by menu listings that don't expand into sizes
  /// (the menu endpoint returns `originalPrice`/`discountedPrice`).
  final double? listPrice;
  final double? calories;
  final double? protein;
  final double? fats;
  final double? carbs;

  const MealModel({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.categoryId,
    this.categoryName,
    this.sizes = const [],
    this.ingredients = const [],
    this.listPrice,
    this.calories,
    this.protein,
    this.fats,
    this.carbs,
  });

  /// Cheapest size price for display, falling back to the flat menu price
  /// when the meal has no per-size pricing.
  double get basePrice => sizes.isNotEmpty
      ? sizes.map((s) => s.price).reduce((a, b) => a < b ? a : b)
      : (listPrice ?? 0);

  /// Convert API meal to the UI's existing MenuItem model.
  MenuItem toMenuItem() => MenuItem(
        id: id,
        name: name,
        description: description ?? '',
        price: basePrice,
        imageUrl: imageUrl ?? '',
        category: categoryName ?? '',
        nutrition: NutritionInfo(
          calories: (calories ?? 0).toInt(),
          protein: protein ?? 0,
          fats: fats ?? 0,
          carbs: carbs ?? 0,
        ),
        // Only real sizes (those carrying a MealSizeId) become selectable
        // portions. No hard-coded fallback size: if the meal has none, the
        // detail screen blocks add-to-cart instead of sending a fake sizeId.
        portions: sizes
            .where((s) => s.id != null && s.id!.isNotEmpty)
            .map((s) => MenuPortion(id: s.id!, name: s.name))
            .toList(),
        ingredients: ingredients.map((i) => i.toIngredient()).toList(),
      );

  factory MealModel.fromJson(Map<String, dynamic> json) {
    final sizesList = json['sizes'] ?? json['mealSizes'] ?? [];
    var ingList = json['ingredients'] ??
        json['mealIngredients'] ??
        json['ingredientsList'] ??
        [];
    // Ingredients are nested per-size; fall back to the first size's list so
    // menu cards / list views still show something at the meal level.
    if ((ingList is! List || ingList.isEmpty) &&
        sizesList is List &&
        sizesList.isNotEmpty) {
      final first = sizesList.first;
      if (first is Map && first['ingredients'] is List) {
        ingList = first['ingredients'];
      }
    }
    Map<String, dynamic> nutrition =
        json['nutrition'] as Map<String, dynamic>? ??
            json['nutritionInfo'] as Map<String, dynamic>? ??
            {};
    // GET /meals/:id returns nutrition nested inside each size, not at the
    // meal root. Fall back to the first size's nutrition so the detail screen
    // shows real macros instead of zeros. // TODO: confirm nutrition sub-keys.
    if (nutrition.isEmpty && sizesList is List && sizesList.isNotEmpty) {
      final first = sizesList.first;
      if (first is Map && first['nutrition'] is Map) {
        nutrition = Map<String, dynamic>.from(first['nutrition'] as Map);
      }
    }

    return MealModel(
      id: json['mealId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      description: json['description']?.toString(),
      imageUrl: json['imgUrl']?.toString() ??
          json['imageUrl']?.toString() ??
          json['imageUri']?.toString() ??
          json['image']?.toString() ??
          json['imageURL']?.toString() ??
          json['mealImage']?.toString() ??
          json['mealImageUrl']?.toString() ??
          json['photoUrl']?.toString() ??
          json['pictureUrl']?.toString(),
      categoryId: json['categoryId']?.toString(),
      categoryName: json['categoryName']?.toString() ?? json['category']?.toString(),
      sizes: (sizesList as List)
          .map((e) => MealSizeModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      ingredients: (ingList is List)
          ? ingList
              .map((e) => e is Map<String, dynamic>
                  ? IngredientModel.fromJson(e)
                  : IngredientModel(name: e.toString()))
              .toList()
          : [],
      listPrice: _toDouble(json['discountedPrice']) ??
          _toDouble(json['originalPrice']) ??
          _toDouble(json['price']),
      calories: _toDouble(nutrition['calories'] ??
          json['calories'] ??
          json['lowestCalorieOption']),
      protein: _toDouble(nutrition['protein'] ?? json['protein']),
      fats: _toDouble(nutrition['totalFat'] ?? nutrition['fats'] ?? nutrition['fat'] ?? json['fats'] ?? json['fat']),
      carbs: _toDouble(nutrition['totalCarbohydrate'] ?? nutrition['carbs'] ?? json['carbs']),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

// ── Menu Category ───────────────────────────────────────────────────────
class MenuCategoryModel {
  final String? id;
  final String name;
  final List<MealModel> meals;

  const MenuCategoryModel({
    this.id,
    required this.name,
    this.meals = const [],
  });

  factory MenuCategoryModel.fromJson(Map<String, dynamic> json) {
    final mealsList = json['meals'] ?? json['items'] ?? [];
    final categoryName = json['name']?.toString() ??
        json['categoryName']?.toString() ??
        'Other';
    return MenuCategoryModel(
      id: json['categoryId']?.toString() ?? json['id']?.toString(),
      name: categoryName,
      meals: (mealsList as List).map((e) {
        final mealJson = Map<String, dynamic>.from(e as Map);
        // Meals nested under a category don't repeat the category name, so
        // inherit it from the parent here. This is what powers the category
        // filter chips on both the restaurant menu and subscribe screens.
        if (mealJson['categoryName'] == null && mealJson['category'] == null) {
          mealJson['categoryName'] = categoryName;
        }
        return MealModel.fromJson(mealJson);
      }).toList(),
    );
  }
}

// ── Full Menu Response ──────────────────────────────────────────────────
class MenuResponseModel {
  final String? restaurantId;
  final String? restaurantName;
  final List<MenuCategoryModel> categories;
  final List<Branch> branches;
  final String? defaultBranchId;

  const MenuResponseModel({
    this.restaurantId,
    this.restaurantName,
    this.categories = const [],
    this.branches = const [],
    this.defaultBranchId,
  });

  /// Flatten to all meals.
  List<MealModel> get allMeals =>
      categories.expand((c) => c.meals).toList();

  /// Convert to the UI's existing Restaurant model.
  Restaurant toRestaurant({
    String? bannerUrl,
    String? logoUrl,
    String? location,
    String? phone,
    double rating = 0,
    List<OpeningHours>? openingHours,
  }) {
    return Restaurant(
      id: restaurantId ?? '',
      name: restaurantName ?? 'Restaurant',
      bannerUrl: bannerUrl ?? '',
      logoUrl: logoUrl ?? '',
      location: location ?? '',
      phone: phone ?? '',
      rating: rating,
      openingHours: openingHours ?? const [],
      categories: categories.map((c) => c.name).toList(),
      branches: branches,
      defaultBranchId: defaultBranchId,
      menu: allMeals.map((m) => m.toMenuItem()).toList(),
    );
  }

  factory MenuResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;

    // Handle case where response is a list of categories
    if (data is List) {
      return MenuResponseModel(
        categories: data
            .map((e) => MenuCategoryModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    }

    final catList = data['categories'] ?? data['menu'] ?? [];
    final branchRaw = data['branches'] ?? data['branchList'] ?? [];
    final branchList = (branchRaw is List)
        ? branchRaw
            .whereType<Map>()
            .map((b) => Branch.fromJson(Map<String, dynamic>.from(b)))
            .where((b) => b.id.isNotEmpty)
            .toList()
        : <Branch>[];
    return MenuResponseModel(
      restaurantId: data['restaurantId']?.toString() ?? data['id']?.toString(),
      restaurantName: data['restaurantName']?.toString() ?? data['name']?.toString(),
      categories: (catList is List)
          ? catList
              .map((e) => MenuCategoryModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      branches: branchList,
      defaultBranchId: (data['defaultBranchId'] ??
              data['mainBranchId'] ??
              data['branchId'])
          ?.toString(),
    );
  }
}


