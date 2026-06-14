class NutritionInfo {
  final int calories;
  final double protein;
  final double fats;
  final double carbs;

  const NutritionInfo({
    required this.calories,
    required this.protein,
    required this.fats,
    required this.carbs,
  });
}

class ExtraItem {
  final String id;
  final String name;
  final double price;

  const ExtraItem({required this.id, required this.name, required this.price});
}

class Ingredient {
  final String name;
  final String amount;

  const Ingredient({required this.name, required this.amount});
}

class MenuPortion {
  final String id;
  final String name;
  const MenuPortion({required this.id, required this.name});
}

class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final NutritionInfo nutrition;
  final List<ExtraItem> extras;
  final List<Ingredient> ingredients;
  final List<MenuPortion> portions;

  const MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.nutrition,
    this.extras = const [],
    this.ingredients = const [],
    // No hard-coded default size. Real sizes (with their MealSizeId GUID) are
    // loaded from GET /meals/:id on the detail screen.
    this.portions = const [],
  });
}


