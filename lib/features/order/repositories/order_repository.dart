import 'package:slyce/core/constants/api_endpoints.dart';
import 'package:slyce/core/network/dio_client.dart';
import 'package:slyce/core/storage/secure_storage.dart';
import 'package:slyce/features/order/models/order_model.dart';

/// Repository for customer order API calls.
///
/// Orders are customer-scoped in Slyce.json:
///   GET /v1/customers/:customerId/orders       -> { ordersHistory: [...] }
///   GET /v1/customers/:customerId/orders/:id    -> single order details
class OrderRepository {
  final _client = DioClient.instance;
  final _storage = SecureStorage.instance;

  /// List all orders for the current customer.
  Future<List<OrderModel>> getOrders() async {
    final customerId = await _storage.getCustomerId();
    if (customerId == null || customerId.isEmpty) return [];

    final response = await _client.get(ApiEndpoints.customerOrders(customerId));
    final data = response.data;

    List items;
    if (data is List) {
      items = data;
    } else if (data is Map) {
      items = (data['ordersHistory'] ??
          data['orders'] ??
          data['data'] ??
          []) as List;
    } else {
      items = [];
    }

    return items
        .whereType<Map>()
        .map((e) => OrderModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Get a specific order's details by ID.
  Future<OrderModel> getOrder(String id) async {
    final customerId = await _storage.getCustomerId();
    if (customerId == null || customerId.isEmpty) {
      return OrderModel(id: id, status: 'Pending');
    }

    final response =
        await _client.get(ApiEndpoints.customerOrderById(customerId, id));
    final data = response.data;
    if (data is Map) {
      return OrderModel.fromJson(Map<String, dynamic>.from(data));
    }
    return OrderModel(id: id, status: 'Pending');
  }
}
