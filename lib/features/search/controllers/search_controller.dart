import 'dart:async';

import 'package:get/get.dart';
import 'package:slyce/features/home/controllers/home_controller.dart';
import 'package:slyce/features/home/models/menu_item.dart';
import 'package:slyce/features/home/models/meal_model.dart';
import 'package:slyce/features/home/models/restaurant.dart';
import 'package:slyce/features/home/repositories/menu_repository.dart';
import 'package:slyce/features/profile/controllers/address_controller.dart';
import 'package:slyce/features/profile/models/address_model.dart';

/// A single matched menu item together with the restaurant it belongs to.
///
/// Every search result for an item carries its owning restaurant so the detail
/// screen opens with the correct restaurant context (and orderable branch),
/// not just the first one in the feed.
class SearchItemResult {
  final MenuItem item;
  final Restaurant restaurant;
  const SearchItemResult({required this.item, required this.restaurant});
}

/// GetX controller for the home search.
///
/// Item search is backend-driven: it calls `GET /v1/meals/nearby` so results
/// reflect the full catalogue of meals near the customer, not just the
/// restaurants already loaded in the home feed. Restaurant matches are still
/// resolved locally against the feed (the endpoint only returns meals).
///
/// The owning restaurant for a returned meal is recovered from the locally
/// indexed feed pool (by mealId) so the detail screen can still order it. When
/// a meal is not in the loaded feed, we fall back to the feed's placeholder
/// restaurant.
class SearchController extends GetxController {
  final _menuRepo = MenuRepository();

  HomeController get _home => Get.isRegistered<HomeController>()
      ? Get.find<HomeController>()
      : Get.put(HomeController());

  // ── Observables ──────────────────────────────────
  final query = ''.obs;
  final hasSearched = false.obs;
  // True while a search (backend request or first-time menu indexing) runs.
  final isIndexing = false.obs;
  // True when a search was attempted but the customer has no delivery location
  // yet. Search is a delivery search, so it MUST be tied to coordinates; we
  // surface a prompt instead of returning unrelated local results.
  final locationMissing = false.obs;
  // True when the API search failed (network/parse). Search is API-only, so we
  // show an error state rather than falling back to stale local results.
  final searchError = false.obs;

  final restaurantResults = <Restaurant>[].obs;
  final itemResults = <SearchItemResult>[].obs;

  // Cached pool of every menu item across the nearby restaurants, each tagged
  // with its owning restaurant. Built lazily from the home feed and used to
  // recover the restaurant/branch context for a backend search hit.
  final List<SearchItemResult> _itemPool = [];
  bool _indexed = false;
  // Coordinates the nearby index was last built for. The nearby index maps a
  // meal to the restaurant (and its orderable branch) that actually owns it,
  // which is the only reliable way to order a searched meal: neither
  // /meals/nearby nor /meals/:id returns a restaurant/branch.
  ({double lat, double lng})? _indexedCoords;

  // Debounce + stale-guard for the backend search.
  Timer? _debounce;
  int _searchSeq = 0;

  @override
  void onInit() {
    super.onInit();
    // Pre-build the index from whatever the home feed already has so we can map
    // search hits back to their restaurant as soon as results arrive.
    ensureIndex();
    _watchDeliveryLocation();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }

  /// Watch the customer's delivery location. The home search is a delivery
  /// search, so the moment the last usable address is removed (no coordinates
  /// left) any previous search must be discarded. Otherwise stale "history"
  /// results could still be opened and added to the cart without a delivery
  /// location.
  void _watchDeliveryLocation() {
    try {
      final addressCtrl = Get.find<AddressController>();
      everAll(
        [addressCtrl.addresses, addressCtrl.selectedAddress],
        (_) {
          if (hasSearched.value && !_hasDeliveryLocation(addressCtrl)) {
            clear();
          }
        },
      );
    } catch (_) {
      // AddressController not registered yet; nothing to watch.
    }
  }

  /// True when there is at least one delivery address with coordinates (the
  /// selected one, or any saved address), mirroring [_resolveCoordinates].
  bool _hasDeliveryLocation(AddressController addressCtrl) {
    final selected = addressCtrl.selectedAddress.value;
    if (selected != null &&
        selected.latitude != null &&
        selected.longitude != null) {
      return true;
    }
    return addressCtrl.addresses
        .any((a) => a.latitude != null && a.longitude != null);
  }

  /// Build (once) the searchable pool of items belonging to the nearby
  /// restaurants. The menu is per-restaurant, so we fetch each restaurant's
  /// menu by its restaurantId and tag every item with that restaurant.
  Future<void> ensureIndex({bool force = false}) async {
    if (_indexed && !force) return;
    try {
      final pool = <SearchItemResult>[];
      for (final r in _home.restaurants) {
        // Use the menu already attached to the restaurant if present.
        var items = r.menu;
        // Otherwise fetch it (the menu is keyed by restaurantId).
        if (items.isEmpty && r.id.isNotEmpty) {
          try {
            final resp = await _menuRepo.getMenu(r.id);
            items = resp.allMeals.map((m) => m.toMenuItem()).toList();
          } catch (_) {
            items = const [];
          }
        }
        for (final it in items) {
          pool.add(SearchItemResult(item: it, restaurant: r));
        }
      }
      _itemPool
        ..clear()
        ..addAll(pool);
      _indexed = true;
    } catch (_) {
      // Indexing is best-effort; the backend search still works without it.
    }
    // Re-run the current query (e.g. after a pull-to-refresh re-index).
    if (force && query.value.isNotEmpty) _runBackendSearch(query.value);
  }

  /// Entry point from the search field. Debounced so we don't fire a request
  /// on every keystroke.
  void search(String term) {
    final trimmed = term.trim();
    query.value = trimmed;
    _debounce?.cancel();

    if (trimmed.isEmpty) {
      _searchSeq++; // cancel any in-flight result
      restaurantResults.clear();
      itemResults.clear();
      hasSearched.value = false;
      isIndexing.value = false;
      locationMissing.value = false;
      searchError.value = false;
      return;
    }

    hasSearched.value = true;
    locationMissing.value = false;
    searchError.value = false;
    // Instant local restaurant matches for a snappy feel; items follow from the
    // backend a moment later.
    _applyRestaurantFilter(trimmed);
    isIndexing.value = true;
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _runBackendSearch(trimmed);
    });
  }

  void _applyRestaurantFilter(String term) {
    final q = term.toLowerCase();
    restaurantResults.value = _home.restaurants
        .where((r) => r.name.toLowerCase().contains(q))
        .toList();
  }

  /// Query the backend `meals/nearby` search for the matching items.
  Future<void> _runBackendSearch(String term) async {
    if (term != query.value) return; // superseded by a newer keystroke
    final seq = ++_searchSeq;
    isIndexing.value = true;
    try {
      _applyRestaurantFilter(term);

      final coords = await _resolveCoordinates();
      if (coords == null) {
        // Search is a delivery search: it MUST be tied to a location. Without a
        // delivery address we can't query meals near the customer, so prompt
        // for one instead of showing unrelated local feed results.
        if (seq != _searchSeq) return;
        locationMissing.value = true;
        restaurantResults.clear();
        itemResults.clear();
        return;
      }
      locationMissing.value = false;

      final meals = await _menuRepo.searchMealsNearby(
        term: term,
        latitude: coords.lat,
        longitude: coords.lng,
      );
      if (seq != _searchSeq) return; // a newer search won the race

      // Ensure the item→restaurant index covers the real nearby restaurants
      // (each carrying its orderable branch), not just the home feed, so a
      // search hit resolves to the branch that truly owns it instead of a
      // placeholder. This is what prevents the cart API from rejecting
      // add-to-cart with "Meal '<id>' does not belong to the restaurant".
      await _ensureNearbyIndex(coords);
      if (seq != _searchSeq) return;

      itemResults.value = meals
          .map((m) => SearchItemResult(
                item: m.toMenuItem(),
                restaurant: _restaurantForMeal(m),
              ))
          .toList();
    } catch (_) {
      if (seq != _searchSeq) return;
      // Search is API-only: on failure, surface an error instead of showing
      // stale local results.
      itemResults.clear();
      searchError.value = true;
    } finally {
      if (seq == _searchSeq) isIndexing.value = false;
    }
  }

  /// Find the restaurant (with its orderable branch) that owns [mealId], so a
  /// search result opens with full ordering context. Falls back to the feed's
  /// placeholder restaurant when the meal isn't in the indexed pool.
  Restaurant _restaurantForMeal(MealModel meal) {
    // 1) Prefer the restaurant/branch the API attaches to the meal itself, so a
    //    nearby-search hit that isn't in the loaded home feed still opens with
    //    the branch that actually owns it. Pairing a meal with the branch of a
    //    different restaurant is exactly what makes the cart API reject
    //    add-to-cart with "Meal '<id>' does not belong to the restaurant".
    final branchId = meal.branchId;
    if ((meal.restaurantId != null && meal.restaurantId!.isNotEmpty) &&
        (branchId != null && branchId.isNotEmpty)) {
      return Restaurant(
        id: meal.restaurantId!,
        name: meal.restaurantName ?? 'Restaurant',
        bannerUrl: '',
        logoUrl: '',
        location: '',
        phone: '',
        rating: 0,
        openingHours: const [],
        menu: const [],
        categories: const [],
        defaultBranchId: branchId,
      );
    }
    // 2) Otherwise recover it from the locally indexed feed pool by mealId.
    for (final e in _itemPool) {
      if (e.item.id == meal.id) return e.restaurant;
    }
    // 3) Last resort: the feed's placeholder restaurant.
    return _home.feedRestaurant;
  }

  /// Build (and cache) the item→restaurant index from the actual restaurants
  /// near [coords]. Because the meal endpoints don't carry a restaurant/branch,
  /// the only way to know which branch owns a searched meal is to look up which
  /// nearby restaurant's menu contains it. Each restaurant from
  /// `top-rated/nearby` carries its orderable branch (`defaultBranchId`), so a
  /// match here gives the detail screen a restaurant it can actually order
  /// from. Menus are fetched in parallel to keep the extra latency small.
  Future<void> _ensureNearbyIndex(({double lat, double lng}) coords) async {
    if (_indexedCoords != null && _sameCoords(_indexedCoords!, coords)) return;
    try {
      final restaurants = await _menuRepo.getTopRatedRestaurantsNearby(
        latitude: coords.lat,
        longitude: coords.lng,
      );
      final menus = await Future.wait(
        restaurants.map((r) async {
          if (r.menu.isNotEmpty || r.id.isEmpty) return r.menu;
          try {
            final resp = await _menuRepo.getMenu(r.id);
            return resp.allMeals.map((m) => m.toMenuItem()).toList();
          } catch (_) {
            return <MenuItem>[];
          }
        }),
      );
      final pool = <SearchItemResult>[];
      for (var i = 0; i < restaurants.length; i++) {
        for (final it in menus[i]) {
          // Keep the restaurant (with its branch) as the owner of each item.
          pool.add(SearchItemResult(item: it, restaurant: restaurants[i]));
        }
      }
      if (pool.isNotEmpty) {
        _itemPool
          ..clear()
          ..addAll(pool);
        _indexed = true;
        _indexedCoords = coords;
      }
    } catch (_) {
      // Best-effort: fall back to the home-feed pool / placeholder restaurant.
    }
  }

  bool _sameCoords(
    ({double lat, double lng}) a,
    ({double lat, double lng}) b,
  ) =>
      (a.lat - b.lat).abs() < 0.0001 && (a.lng - b.lng).abs() < 0.0001;

  /// Resolve the customer's coordinates from their selected delivery address
  /// (falling back to the first saved address that has coordinates), mirroring
  /// how the home feed picks a location. Returns null when none is available.
  Future<({double lat, double lng})?> _resolveCoordinates() async {
    try {
      final addressCtrl = Get.find<AddressController>();
      if (addressCtrl.addresses.isEmpty) {
        await addressCtrl.loadAddresses();
      }
      AddressModel? source = addressCtrl.selectedAddress.value;
      if (source == null ||
          source.latitude == null ||
          source.longitude == null) {
        for (final a in addressCtrl.addresses) {
          if (a.latitude != null && a.longitude != null) {
            source = a;
            break;
          }
        }
      }
      if (source?.latitude != null && source?.longitude != null) {
        return (lat: source!.latitude!, lng: source.longitude!);
      }
    } catch (_) {
      // No address controller / failed load — caller falls back to local pool.
    }
    return null;
  }

  bool get hasResults =>
      restaurantResults.isNotEmpty || itemResults.isNotEmpty;

  void clear() {
    _debounce?.cancel();
    _searchSeq++;
    query.value = '';
    hasSearched.value = false;
    isIndexing.value = false;
    locationMissing.value = false;
    searchError.value = false;
    restaurantResults.clear();
    itemResults.clear();
  }
}
