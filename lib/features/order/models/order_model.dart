// Order models matching the backend's order schema (Slyce.json):
//   GET /v1/customers/:customerId/orders          -> { ordersHistory: [ ... ] }
//   GET /v1/customers/:customerId/orders/:id      -> { orderId, createdAt,
//        deliveryAddress, orderItems: [ ... ], orderStatus, paymentMethod }

class OrderItemModel {
  final String? id;
  final String? mealId;
  final String? mealName;
  final String? sizeName;
  final int quantity;
  /// Line total captured at order time (`priceAtOrder`). This is the total for
  /// the whole line (already includes quantity), NOT the per-unit price.
  final double price;
  final String? imageUrl;

  const OrderItemModel({
    this.id,
    this.mealId,
    this.mealName,
    this.sizeName,
    this.quantity = 1,
    this.price = 0,
    this.imageUrl,
  });

  /// Line total for this item. `priceAtOrder` already accounts for quantity.
  double get totalPrice => price;

  /// Per-unit price derived from the line total (for display only).
  double get unitPrice => quantity > 0 ? price / quantity : price;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    // Some backends nest the meal info under a `meal` (or `product`) object
    // instead of flattening it onto the order item.
    final nested = json['meal'] is Map
        ? Map<String, dynamic>.from(json['meal'] as Map)
        : (json['product'] is Map
            ? Map<String, dynamic>.from(json['product'] as Map)
            : const <String, dynamic>{});
    String? pick(String key) =>
        json[key]?.toString() ?? nested[key]?.toString();
    return OrderItemModel(
      id: json['id']?.toString(),
      mealId: pick('mealId') ??
          pick('meal_id') ??
          pick('mealItemId') ??
          pick('productId') ??
          nested['id']?.toString(),
      mealName: pick('mealName') ??
          pick('meal_name') ??
          pick('name') ??
          'Unknown meal',
      sizeName: pick('sizeName') ??
          pick('size_name') ??
          pick('size'),
      quantity: _toInt(json['quantity']) ?? 1,
      price: _toDouble(json['priceAtOrder'] ?? json['price']) ?? 0,
      imageUrl: pick('imageUrl') ??
          pick('imgUrl') ??
          pick('image') ??
          pick('imageURL') ??
          pick('mealImage') ??
          pick('mealImageUrl') ??
          pick('photoUrl') ??
          pick('pictureUrl'),
    );
  }

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

class OrderModel {
  final String id;
  final String status;
  final List<OrderItemModel> items;
  final double total;
  final double deliveryFee;
  final String? deliveryAddressId;
  /// Human-readable delivery address label ("area, city") from the order
  /// details response.
  final String? deliveryAddress;
  final String? restaurantName;
  final String? restaurantLogo;
  final String? paymentMethod;
  /// Item count from the orders-history list response (`orderItemsCount`).
  /// The list endpoint does not return the items themselves.
  final int? itemsCount;
  final DateTime? createdAt;
  final DateTime? estimatedDelivery;

  const OrderModel({
    required this.id,
    required this.status,
    this.items = const [],
    this.total = 0,
    this.deliveryFee = 0,
    this.deliveryAddressId,
    this.deliveryAddress,
    this.restaurantName,
    this.restaurantLogo,
    this.paymentMethod,
    this.itemsCount,
    this.createdAt,
    this.estimatedDelivery,
  });

  bool get isActive => ![
        'delivered',
        'cancelled',
        'canceled',
        'rejected',
      ].contains(status.toLowerCase());

  /// Number of items to display: the explicit list count when present,
  /// otherwise the number of loaded item rows.
  int get displayItemCount => itemsCount ?? items.length;

  /// Order total. The details endpoint has no total field, so fall back to the
  /// sum of the loaded item line totals.
  double get displayTotal => total > 0
      ? total
      : items.fold<double>(0, (sum, it) => sum + it.totalPrice);

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    final itemsList = data['orderItems'] ?? data['items'] ?? [];

    final items = (itemsList is List)
        ? itemsList
            .whereType<Map>()
            .map((e) => OrderItemModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <OrderItemModel>[];

    // deliveryAddress may be an object { city, area, lat, lng }.
    String? addressLabel;
    final addr = data['deliveryAddress'];
    if (addr is Map) {
      final area = addr['area']?.toString();
      final city = addr['city']?.toString();
      final label = [area, city]
          .where((e) => e != null && e.isNotEmpty)
          .join(', ');
      addressLabel = label.isEmpty ? null : label;
    } else if (addr is String && addr.isNotEmpty) {
      addressLabel = addr;
    }

    return OrderModel(
      id: data['orderId']?.toString() ??
          data['id']?.toString() ??
          '',
      status: data['orderStatus']?.toString() ??
          data['status']?.toString() ??
          'Pending',
      items: items,
      total: _toDouble(
              data['totalPrice'] ?? data['total'] ?? data['totalAmount']) ??
          0,
      deliveryFee:
          _toDouble(data['deliveryFee'] ?? data['delivery_fee']) ?? 0,
      deliveryAddressId: data['deliveryAddressId']?.toString() ??
          data['delivery_address_id']?.toString(),
      deliveryAddress: addressLabel,
      restaurantName: data['restaurantName']?.toString() ??
          data['restaurant_name']?.toString(),
      restaurantLogo: data['restaurantLogo']?.toString() ??
          data['restaurantLogoUrl']?.toString() ??
          data['restaurant_logo']?.toString(),
      paymentMethod: data['paymentMethod']?.toString() ??
          data['payment_method']?.toString(),
      itemsCount: _toInt(data['orderItemsCount'] ?? data['itemsCount']),
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ??
          data['created_at']?.toString() ??
          ''),
      estimatedDelivery: DateTime.tryParse(
          data['estimatedDelivery']?.toString() ??
              data['estimated_delivery']?.toString() ??
              ''),
    );
  }

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
