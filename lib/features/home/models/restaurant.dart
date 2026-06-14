import 'package:slyce/features/home/models/menu_item.dart';

class OpeningHours {
  final String day;
  final String open;
  final String close;

  const OpeningHours({required this.day, required this.open, required this.close});
}

/// A physical branch of a restaurant that can fulfil orders / subscriptions.
class Branch {
  final String id;
  final String name;
  final String? area;
  final String? city;
  final String? phone;
  final List<OpeningHours> openingHours;

  const Branch({
    required this.id,
    required this.name,
    this.area,
    this.city,
    this.phone,
    this.openingHours = const [],
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    final d = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final hoursRaw = d['workingHours'] ?? d['openingHours'] ?? [];
    return Branch(
      id: (d['id'] ?? d['branchId'] ?? '').toString(),
      name: (d['branchName'] ?? d['name'] ?? 'Branch').toString(),
      area: d['area']?.toString(),
      city: d['city']?.toString(),
      phone:
          (d['phoneNumber'] ?? d['phone'] ?? d['contactNumber'])?.toString(),
      openingHours: (hoursRaw is List)
          ? hoursRaw
              .whereType<Map>()
              .map((h) => OpeningHours(
                    day: h['day']?.toString() ?? '',
                    open: (h['open'] ?? h['openTime'] ?? '').toString(),
                    close: (h['close'] ?? h['closeTime'] ?? '').toString(),
                  ))
              .toList()
          : const <OpeningHours>[],
    );
  }

  /// Combined "area, city" location label (may be empty).
  String get address => [area, city]
      .where((e) => e != null && e.isNotEmpty)
      .join(', ');

  /// Human-friendly label combining the branch name and its location.
  String get displayName {
    final loc = address;
    return loc.isEmpty ? name : '$name — $loc';
  }
}

class Restaurant {
  final String id;
  final String name;
  final String bannerUrl;
  final String logoUrl;
  final String location;
  final String phone;
  final double rating;
  final List<OpeningHours> openingHours;
  final List<MenuItem> menu;
  final List<String> categories;
  final List<Branch> branches;
  final String? defaultBranchId;

  const Restaurant({
    required this.id,
    required this.name,
    required this.bannerUrl,
    required this.logoUrl,
    required this.location,
    required this.phone,
    required this.rating,
    required this.openingHours,
    required this.menu,
    required this.categories,
    this.branches = const [],
    this.defaultBranchId,
  });

  /// The branch id to use by default for orders / subscriptions, if known.
  String? get primaryBranchId =>
      (defaultBranchId != null && defaultBranchId!.isNotEmpty)
          ? defaultBranchId
          : (branches.isNotEmpty ? branches.first.id : null);

  List<MenuItem> menuByCategory(String category) =>
      menu.where((item) => item.category == category).toList();
}
