/// The customer's saved profile as returned by `GET /v1/customers/profile`.
///
/// The backend returns the chosen allergens and diet preferences as *ids*
/// only; their display names are resolved from the `GET /v1/food/allergens`
/// and `GET /v1/food/food-preferences` lookup lists.
class CustomerProfileModel {
  final String? gender;
  final String? activityRate;
  final double? weightKg;
  final double? heightCm;
  final List<String> allergenIds;
  final List<String> dietPreferenceIds;

  const CustomerProfileModel({
    this.gender,
    this.activityRate,
    this.weightKg,
    this.heightCm,
    this.allergenIds = const [],
    this.dietPreferenceIds = const [],
  });

  factory CustomerProfileModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return CustomerProfileModel(
      gender: data['gender']?.toString(),
      activityRate: data['activityRate']?.toString(),
      weightKg: _toDouble(data['weightKg']),
      heightCm: _toDouble(data['heightCm']),
      allergenIds: _toIdList(data['allergens'] ?? data['allergenIds']),
      dietPreferenceIds:
          _toIdList(data['dietPreferences'] ?? data['dietPreferenceIds']),
    );
  }

  /// Accepts either a list of plain id strings or a list of `{ id, name }`
  /// objects and returns just the ids.
  static List<String> _toIdList(dynamic value) {
    if (value is! List) return const [];
    final ids = <String>[];
    for (final e in value) {
      if (e is String) {
        if (e.isNotEmpty) ids.add(e);
      } else if (e is Map) {
        final id = (e['id'] ??
                e['allergenId'] ??
                e['dietPreferenceId'] ??
                e['foodPreferenceId'] ??
                '')
            .toString();
        if (id.isNotEmpty) ids.add(id);
      }
    }
    return ids;
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
