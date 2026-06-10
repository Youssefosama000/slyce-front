import 'package:get/get.dart';
import 'package:slyce/core/network/api_exceptions.dart';
import 'package:slyce/features/home/models/menu_item.dart';
import 'package:slyce/features/home/models/restaurant.dart';
import 'package:slyce/features/home/repositories/menu_repository.dart';
import 'package:slyce/features/profile/controllers/address_controller.dart';
import 'package:slyce/features/profile/models/address_model.dart';

/// GetX controller for the home screen data.
///
/// All data is API-driven. There are no hard-coded restaurants, coordinates,
/// categories, or fallback search terms: the feed reflects exactly what the
/// backend returns for the customer's saved location.
class HomeController extends GetxController {
  final _menuRepo = MenuRepository();

  // ── Observables ────────────────────────────────────────
  final isLoading = false.obs;
  final errorMessage = ''.obs;
  final restaurants = <Restaurant>[].obs;
  // Human-readable reason the restaurants list is empty (e.g. an HTTP error or
  // a missing delivery address). Surfaced in the home empty state.
  final restaurantsError = ''.obs;
  final recommended = <MenuItem>[].obs;
  final allMeals = <MenuItem>[].obs;

  // Id of the restaurant whose menu populated [allMeals]/[recommended]. Lets
  // other screens (e.g. the subscribe meal picker) reuse the already-fetched
  // menu instead of re-requesting it (avoids a slow duplicate menu fetch).
  final feedMealsRestaurantId = ''.obs;

  /// Restaurant context used when opening a meal from the feed. When the
  /// restaurants list is empty this is an empty (data-less) Restaurant so the
  /// meal detail screen, which requires a non-null restaurant, can still open.
  /// It carries no fabricated content — every field is blank.
  Restaurant get feedRestaurant => restaurants.isNotEmpty
      ? restaurants.first
      : const Restaurant(
          id: '',
          name: '',
          bannerUrl: '',
          logoUrl: '',
          location: '',
          phone: '',
          rating: 0,
          openingHours: [],
          menu: [],
          categories: [],
        );

  @override
  void onInit() {
    super.onInit();
    // Keep the feed in sync with the selected delivery address. Selecting a
    // different address, adding the first address, or deleting addresses (which
    // can reset the selection to another address or to null) all re-run the
    // feed, so a stale location label and stale restaurants never linger.
    final addressCtrl = Get.find<AddressController>();
    ever<AddressModel?>(addressCtrl.selectedAddress, (_) => loadData());
    loadData();
  }

  Future<void> loadData() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      await _fetchData();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _fetchData() async {
    // Reset the feed up-front so data from a previous location is never shown
    // when the new location returns nothing (empty `nearby` or empty menu), or
    // when there is no longer any saved delivery address at all.
    restaurantsError.value = '';
    errorMessage.value = '';
    restaurants.clear();
    recommended.clear();
    allMeals.clear();
    feedMealsRestaurantId.value = '';

    // 1. Resolve the customer's coordinates from their SELECTED delivery
    //    address (chosen in the header dropdown), falling back to the first
    //    saved address that has coordinates. No device GPS and no hard-coded
    //    coordinates: if no address has coordinates, the nearby feed stays empty.
    double? latitude;
    double? longitude;
    try {
      final addressCtrl = Get.find<AddressController>();
      if (addressCtrl.addresses.isEmpty) {
        await addressCtrl.loadAddresses();
      }
      AddressModel? source = addressCtrl.selectedAddress.value;
      if (source == null ||
          source.latitude == null ||
          source.longitude == null) {
        for (final address in addressCtrl.addresses) {
          if (address.latitude != null && address.longitude != null) {
            source = address;
            break;
          }
        }
      }
      latitude = source?.latitude;
      longitude = source?.longitude;
    } on ApiException catch (_) {
      restaurantsError.value =
          'We couldn\'t load your delivery address. Pull down to refresh.';
    } catch (_) {
      restaurantsError.value =
          'We couldn\'t load your delivery address. Pull down to refresh.';
    }

    if (latitude == null || longitude == null) {
      if (restaurantsError.value.isEmpty) {
        restaurantsError.value =
            'Add a delivery address to see top-rated restaurants near you.';
      }
      return;
    }

    // 2. Load the top-rated restaurants near that location.
    try {
      final restaurantList = await _menuRepo.getTopRatedRestaurantsNearby(
        latitude: latitude,
        longitude: longitude,
      );
      if (restaurantList.isNotEmpty) {
        restaurants.value = restaurantList;
      } else {
        // No restaurants for this location — show the clean empty state only,
        // with no technical detail.
        restaurantsError.value = '';
      }
    } on ApiException catch (_) {
      restaurantsError.value =
          'We couldn\'t load restaurants right now. Pull down to refresh.';
    } catch (_) {
      restaurantsError.value =
          'We couldn\'t load restaurants right now. Pull down to refresh.';
    }

    // 3. Load meals for the feed from each restaurant's menu.
    //    The menu is per-RESTAURANT (one menu per restaurant) and is fetched
    //    with the restaurantId — `r.id` resolves to the restaurantId returned
    //    by the `nearby` endpoint. (Ordering, separately, uses the nearby
    //    branchId.)
    for (final id
        in restaurants.map((r) => r.id).where((id) => id.isNotEmpty)) {
      try {
        final menuResponse = await _menuRepo.getMenu(id);
        if (menuResponse.allMeals.isNotEmpty) {
          final items =
              menuResponse.allMeals.map((m) => m.toMenuItem()).toList();
          recommended.value = items.take(6).toList();
          allMeals.value = items;
          feedMealsRestaurantId.value = id;
          errorMessage.value = '';
          return;
        }
      } on ApiException catch (e) {
        errorMessage.value = e.message;
      } catch (_) {
        // Try the next restaurant.
      }
    }
  }

  @override
  Future<void> refresh() => loadData();
}
