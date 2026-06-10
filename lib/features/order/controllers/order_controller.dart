import 'package:get/get.dart';
import 'package:slyce/core/network/api_exceptions.dart';
import 'package:slyce/features/order/models/order_model.dart';
import 'package:slyce/features/order/repositories/order_repository.dart';

/// GetX controller for order history and tracking.
class OrderController extends GetxController {
  final _orderRepo = OrderRepository();

  // ── Observables ─────────────────────────────────────────────────────
  final isLoading = false.obs;
  final errorMessage = ''.obs;
  final orders = <OrderModel>[].obs;
  final selectedOrder = Rxn<OrderModel>();

  @override
  void onInit() {
    super.onInit();
    loadOrders();
  }

  /// Load all orders from API.
  Future<void> loadOrders() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      orders.value = await _orderRepo.getOrders();
    } on ApiException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'Failed to load orders.';
    } finally {
      isLoading.value = false;
    }
  }

  /// Load a single order's details.
  Future<void> loadOrder(String id) async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      selectedOrder.value = await _orderRepo.getOrder(id);
    } on ApiException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'Failed to load order details.';
    } finally {
      isLoading.value = false;
    }
  }

  List<OrderModel> get activeOrders =>
      orders.where((o) => o.isActive).toList();

  List<OrderModel> get pastOrders =>
      orders.where((o) => !o.isActive).toList();
}
