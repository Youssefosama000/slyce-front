/// A single weight log entry from the weight history API.
class WeightEntryModel {
  final String? id;
  final double weightKg;
  final DateTime loggedAt;

  const WeightEntryModel({
    this.id,
    required this.weightKg,
    required this.loggedAt,
  });

  double get weightLbs => weightKg * 2.20462;

  factory WeightEntryModel.fromJson(Map<String, dynamic> json) {
    return WeightEntryModel(
      id: json['id']?.toString(),
      weightKg: _toDouble(
              json['weightKg'] ?? json['weight_kg'] ?? json['weight']) ??
          0,
      loggedAt: DateTime.tryParse(
              json['loggedAt']?.toString() ??
                  json['createdAt']?.toString() ??
                  json['date']?.toString() ??
                  '') ??
          DateTime.now(),
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
