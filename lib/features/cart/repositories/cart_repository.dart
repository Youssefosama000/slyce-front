import 'package:slyce/core/constants/api_endpoints.dart';
import 'package:slyce/core/network/dio_client.dart';
import 'package:slyce/features/cart/models/cart_model.dart';

/// Repository for cart API calls.
class CartRepository {
  final _client = DioClient.instance;

  /// View the current cart.
  Future<CartModel> getCart() async {
    final response = await _client.get(ApiEndpoints.cart);
    if (response.data == null || response.data is! Map<String, dynamic>) {
      return const CartModel();
    }
    return CartModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Add an item to the cart.
  ///
  /// Body must match Slyce.json exactly:
  /// `{ branchId, mealId, sizeId, quantity }`.
  Future<void> addToCart({
    required String mealId,
    required String sizeId,
    String branchId = '',
    int quantity = 1,
  }) async {
    await _client.post(
      ApiEndpoints.cart,
      data: {
        'branchId': branchId,
        'mealId': mealId,
        'sizeId': sizeId,
        'quantity': quantity,
      },
    );
  }

  /// Delete (clear) the entire cart.
  Future<void> deleteCart() async {
    await _client.delete(ApiEndpoints.cart);
  }

  /// Change the quantity of a specific cart line.
  ///
  /// Body must match the Slyce collection's "Change item qty" request exactly:
  /// `{ mealId, sizeId, quantity }` → PATCH /cart/items/quantity.
  Future<void> updateItemQuantity({
    required String mealId,
    required String sizeId,
    required int quantity,
  }) async {
    await _client.patch(
      ApiEndpoints.cartItemQuantity,
      data: {
        'mealId': mealId,
        'sizeId': sizeId,
        'quantity': quantity,
      },
    );
  }

  /// Remove a specific line from the cart.
  ///
  /// DELETE /cart/items with body `{ mealId, sizeId }` (Slyce collection
  /// "Delete item"); the server returns 204 No Content on success.
  Future<void> removeItem({
    required String mealId,
    required String sizeId,
  }) async {
    await _client.delete(
      ApiEndpoints.cartItems,
      data: {
        'mealId': mealId,
        'sizeId': sizeId,
      },
    );
  }

  /// Checkout the cart.
  Future<Map<String, dynamic>> checkout({
    required String deliveryAddressId,
    String paymentMethod = 'CashOnDelivery',
  }) async {
    final response = await _client.post(
      ApiEndpoints.checkout,
      data: {
        'deliveryAddressId': deliveryAddressId,
        'paymentMethod': paymentMethod,
      },
    );
    if (response.data == null || response.data is! Map<String, dynamic>) {
      return {'success': true};
    }
    return response.data as Map<String, dynamic>;
  }
}


