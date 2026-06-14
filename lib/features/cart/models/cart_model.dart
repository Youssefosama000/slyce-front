// Cart response models from the API.

class CartItemModel {
  final String? id;
  final String? mealId;
  final String? mealName;
  final String? sizeId;
  final String? sizeName;
  final int quantity;
  final double price;
  final String? imageUrl;
  final String currency;
  // Optional meal description, shown under the name in the cart card when the
  // API provides it. Hidden when absent (never fabricated).
  final String? description;

  const CartItemModel({
    this.id,
    this.mealId,
    this.mealName,
    this.sizeId,
    this.sizeName,
    this.quantity = 1,
    this.price = 0,
    this.imageUrl,
    this.currency = '',
    this.description,
  });

  double get totalPrice => price * quantity;

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      id: json['id']?.toString(),
      mealId: json['mealId']?.toString() ?? json['meal_id']?.toString(),
      mealName: json['mealName']?.toString() ??
          json['meal_name']?.toString() ??
          json['name']?.toString() ??
          'Unknown meal',
      sizeId: json['sizeId']?.toString() ?? json['size_id']?.toString(),
      sizeName: json['sizeName']?.toString() ??
          json['size_name']?.toString() ??
          json['size']?.toString(),
      quantity: _toInt(json['quantity']) ?? 1,
      // Live GET /cart returns the per-unit price as `originalPrice`
      // (with the currency in `currency`); `totalPrice` multiplies by quantity.
      price: _toDouble(json['originalPrice']) ??
          _toDouble(json['unitPrice']) ??
          _toDouble(json['price']) ??
          0,
      imageUrl: json['imageUrl']?.toString() ?? json['imgUrl']?.toString(),
      currency: json['currency']?.toString() ?? '',
      description: json['description']?.toString() ??
          json['mealDescription']?.toString() ??
          json['productDescription']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'mealId': mealId,
        'sizeId': sizeId,
        'quantity': quantity,
      };

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

class CartModel {
  final List<CartItemModel> items;
  final double subtotal;
  final double total;

  const CartModel({
    this.items = const [],
    this.subtotal = 0,
    this.total = 0,
  });

  bool get isEmpty => items.isEmpty;

  /// Currency reported by the cart items (from the live GET /cart `currency`
  /// field). Empty when the cart has no items.
  String get currency {
    for (final item in items) {
      if (item.currency.isNotEmpty) return item.currency;
    }
    return '';
  }

  factory CartModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    final itemsList = data['items'] ?? data['cartItems'] ?? [];

    final items = (itemsList as List)
        .map((e) => CartItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final double subtotal = _toDouble(data['subtotal']) ??
        items.fold<double>(0, (sum, item) => sum + item.totalPrice);
    // The live GET /cart returns only `cartItems` (no totals), so fall back to
    // the computed subtotal instead of 0. (No delivery fee in this app.)
    final double total = _toDouble(data['total']) ??
        _toDouble(data['totalAmount']) ??
        subtotal;

    return CartModel(
      items: items,
      subtotal: subtotal,
      total: total,
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


