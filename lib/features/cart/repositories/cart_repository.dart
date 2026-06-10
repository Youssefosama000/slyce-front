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

  /// Update the quantity of a specific cart item.
  Future<void> updateCartItem({
    required String itemId,
    required int quantity,
  }) async {
    await _client.patch(
      ApiEndpoints.cartItem(itemId),
      data: {'quantity': quantity},
    );
  }

  /// Remove a single item from the cart.
  Future<void> removeCartItem(String itemId) async {
    await _client.delete(ApiEndpoints.cartItem(itemId));
  }

  /// Checkout the cart.
  Future<Map<String, dynamic>> checkout({
    required String deliveryAddressId,
    String paymentMethod = 'card',
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


