/// A selectable lookup option (allergen or diet preference) returned by
/// `GET /v1/food/allergens` and `GET /v1/food/food-preferences`.
///
/// The onboarding profile endpoints (`allergens` / `diet-prefs`) expect the
/// option [id]s, not their display names, so we keep both around.
class FoodOptionModel {
  final String id;
  final String name;

  const FoodOptionModel({required this.id, required this.name});

  factory FoodOptionModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return FoodOptionModel(
      id: (data['id'] ??
              data['allergenId'] ??
              data['dietPreferenceId'] ??
              data['foodPreferenceId'] ??
              '')
          .toString(),
      name: (data['name'] ??
              data['displayName'] ??
              data['title'] ??
              data['label'] ??
              '')
          .toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FoodOptionModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
