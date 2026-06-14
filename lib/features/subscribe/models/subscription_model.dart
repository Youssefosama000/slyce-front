/// Customer subscription summary — one item of the paged response of
/// GET /v1/subscriptions ("Get Customer Subscriptions Summary").
///
/// Real response item (confirmed against a live 200 response):
///   subscriptionId, restaurantId, restaurantName, restaurantLogoUrl,
///   nextDelivery, startDate, totalItems, totalPriceAmount, priceCurrency,
///   status.
///
/// NOTE: the summary does NOT include the billing cycle, time slot, delivery
/// days, or a per-meal breakdown, and Slyce.json exposes no per-subscription
/// detail endpoint to fetch them. They are intentionally not modelled here —
/// showing them would mean inventing data the API never returns.
class SubscriptionModel {
  final String id;
  final String status;
  final String restaurantId;
  final String restaurantName;
  final String restaurantLogoUrl;
  final DateTime? nextDelivery;
  final DateTime? startDate;
  final int totalItems;
  final double totalPriceAmount;
  final String priceCurrency;

  const SubscriptionModel({
    required this.id,
    required this.status,
    this.restaurantId = '',
    this.restaurantName = '',
    this.restaurantLogoUrl = '',
    this.nextDelivery,
    this.startDate,
    this.totalItems = 0,
    this.totalPriceAmount = 0,
    this.priceCurrency = '',
  });

  bool get isActive =>
      !['cancelled', 'Cancelled', 'expired', 'Expired'].contains(status);

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return SubscriptionModel(
      id: data['subscriptionId']?.toString() ?? data['id']?.toString() ?? '',
      status: data['status']?.toString() ?? '',
      restaurantId: data['restaurantId']?.toString() ?? '',
      restaurantName: data['restaurantName']?.toString() ?? '',
      restaurantLogoUrl: data['restaurantLogoUrl']?.toString() ?? '',
      nextDelivery:
          DateTime.tryParse(data['nextDelivery']?.toString() ?? ''),
      startDate: DateTime.tryParse(data['startDate']?.toString() ?? ''),
      totalItems: (data['totalItems'] as num?)?.toInt() ?? 0,
      totalPriceAmount: (data['totalPriceAmount'] as num?)?.toDouble() ?? 0,
      priceCurrency: data['priceCurrency']?.toString() ?? '',
    );
  }
}
