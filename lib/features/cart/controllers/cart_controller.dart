import 'package:get/get.dart';
import 'package:slyce/core/network/api_exceptions.dart';
import 'package:slyce/features/cart/models/cart_model.dart';
import 'package:slyce/features/cart/repositories/cart_repository.dart';
import 'package:slyce/features/home/models/restaurant.dart';
import 'package:slyce/features/home/repositories/menu_repository.dart';
import 'package:slyce/features/profile/models/address_model.dart';

/// GetX controller for cart management via API.
class CartController extends GetxController {
  final _cartRepo = CartRepository();
  final _menuRepo = MenuRepository();

  // ── Observables ─────────────────────────────────────────────────────
  final isLoading = false.obs;
  final isCheckingOut = false.obs;
  final errorMessage = ''.obs;
  final cart = Rxn<CartModel>();
  // The last restaurant the customer added items from, so the cart's
  // "Add Items" button can take them back to that restaurant's menu.
  final lastRestaurant = Rxn<Restaurant>();

  List<CartItemModel> get items => cart.value?.items ?? [];
  int get totalItems => items.fold(0, (sum, i) => sum + i.quantity);
  double get subtotal => cart.value?.subtotal ?? items.fold(0.0, (sum, i) => sum + i.totalPrice);
  double get total => cart.value?.total ?? subtotal;
  // Currency code reported by the cart API (empty when the cart is empty).
  String get currency => cart.value?.currency ?? '';

  @override
  void onInit() {
    super.onInit();
    loadCart();
  }

  /// Load cart from API.
  Future<void> loadCart() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      cart.value = await _cartRepo.getCart();
    } on ApiException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      // Cart may be empty or not exist yet — this is fine
      cart.value = const CartModel();
    } finally {
      isLoading.value = false;
    }
  }

  /// Add item to cart via API.
  Future<bool> addToCart({
    required String mealId,
    required String sizeId,
    String branchId = '',
    int quantity = 1,
    Restaurant? restaurant,
  }) async {
    errorMessage.value = '';
    if (restaurant != null) lastRestaurant.value = restaurant;
    try {
      await _cartRepo.addToCart(
        mealId: mealId,
        sizeId: sizeId,
        branchId: branchId,
        quantity: quantity,
      );
      await loadCart(); // Refresh cart
      return true;
    } on ApiException catch (e) {
      // The backend allows only one branch per cart. Removing the last item
      // can leave a stale branch "lock" on the server: the cart then looks
      // empty in the app, but adding from a different branch is still
      // rejected with HTTP 400 "Cannot mix items from different branches".
      // When our visible cart is empty, clear the stale server cart and retry
      // the add once so the user isn't stuck.
      if (_isDifferentBranchConflict(e) && items.isEmpty) {
        try {
          await _cartRepo.deleteCart();
          await _cartRepo.addToCart(
            mealId: mealId,
            sizeId: sizeId,
            branchId: branchId,
            quantity: quantity,
          );
          await loadCart();
          return true;
        } on ApiException catch (e2) {
          errorMessage.value = e2.message;
          return false;
        } catch (_) {
          errorMessage.value = 'Failed to add item to cart.';
          return false;
        }
      }
      errorMessage.value = e.message;
      return false;
    } catch (_) {
      errorMessage.value = 'Failed to add item to cart.';
      return false;
    }
  }

  /// Whether [e] is the backend's "one branch per cart" rejection: HTTP 400
  /// with a "different branches" message.
  bool _isDifferentBranchConflict(ApiException e) {
    if (e.statusCode != 400) return false;
    return e.message.toLowerCase().contains('different branch');
  }

  /// Change the quantity of a specific cart line via PATCH /cart/items/quantity.
  Future<bool> updateItem({
    required String mealId,
    required String sizeId,
    required int quantity,
  }) async {
    errorMessage.value = '';
    try {
      await _cartRepo.updateItemQuantity(
        mealId: mealId,
        sizeId: sizeId,
        quantity: quantity,
      );
      await loadCart();
      return true;
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (_) {
      errorMessage.value = 'Failed to update item.';
      return false;
    }
  }

  /// Remove a single line from the cart via DELETE /cart/items.
  Future<bool> removeItem({
    required String mealId,
    required String sizeId,
  }) async {
    errorMessage.value = '';
    try {
      await _cartRepo.removeItem(
        mealId: mealId,
        sizeId: sizeId,
      );
      await loadCart();
      return true;
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (_) {
      errorMessage.value = 'Failed to remove item.';
      return false;
    }
  }

  /// Clear the entire cart.
  Future<void> clearCart() async {
    errorMessage.value = '';
    try {
      await _cartRepo.deleteCart();
      cart.value = const CartModel();
    } on ApiException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'Failed to clear cart.';
    }
  }

  /// Whether [address] falls inside the delivery zone of the restaurant the
  /// cart's items came from.
  ///
  /// Mirrors the subscription flow: a customer can only order from a restaurant
  /// that is returned as "nearby" for their delivery location, so an address
  /// outside the restaurant's zone is rejected before checkout.
  ///
  /// Returns `true` when the check can't be performed (unknown restaurant or
  /// missing coordinates) so a valid order is never blocked on missing data;
  /// the backend stays the final authority in that case.
  Future<bool> isAddressInRestaurantZone(AddressModel address) async {
    final restaurantId = lastRestaurant.value?.id;
    if (restaurantId == null || restaurantId.isEmpty) return true;

    final lat = address.latitude;
    final lng = address.longitude;
    if (lat == null || lng == null) return true;

    try {
      final nearby = await _menuRepo.getTopRatedRestaurantsNearby(
        latitude: lat,
        longitude: lng,
      );
      return nearby.any((r) => r.id == restaurantId);
    } catch (_) {
      // Zone lookup failed (e.g. network error) — don't block the order on it.
      return true;
    }
  }

  /// Checkout the cart.
  Future<bool> checkout({
    required String deliveryAddressId,
    String paymentMethod = 'CashOnDelivery',
  }) async {
    isCheckingOut.value = true;
    errorMessage.value = '';

    try {
      await _cartRepo.checkout(
        deliveryAddressId: deliveryAddressId,
        paymentMethod: paymentMethod,
      );
      cart.value = const CartModel();
      return true;
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (_) {
      errorMessage.value = 'Checkout failed. Please try again.';
      return false;
    } finally {
      isCheckingOut.value = false;
    }
  }
}


