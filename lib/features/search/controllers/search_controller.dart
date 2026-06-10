import 'package:get/get.dart';
import 'package:slyce/features/home/controllers/home_controller.dart';
import 'package:slyce/features/home/models/menu_item.dart';
import 'package:slyce/features/home/models/restaurant.dart';
import 'package:slyce/features/home/repositories/menu_repository.dart';

/// A single matched menu item together with the restaurant it belongs to.
///
/// Every search result for an item carries its owning restaurant so the detail
/// screen opens with the correct restaurant context (not just the first one in
/// the feed).
class SearchItemResult {
  final MenuItem item;
  final Restaurant restaurant;
  const SearchItemResult({required this.item, required this.restaurant});
}

/// GetX controller for the home search.
///
/// The search is scoped to the customer's own feed: it matches the nearby
/// restaurants (by name) and the items that belong to those restaurants'
/// menus. It intentionally does NOT call the global / external food-search
/// endpoints, so a result can only ever be a restaurant the customer can
/// actually order from or one of its menu items.
class SearchController extends GetxController {
  final _menuRepo = MenuRepository();

  HomeController get _home => Get.isRegistered<HomeController>()
      ? Get.find<HomeController>()
      : Get.put(HomeController());

  // ── Observables ──────────────────────────────────────────
  final query = ''.obs;
  final hasSearched = false.obs;
  // True while the per-restaurant menus are being indexed for the first time.
  final isIndexing = false.obs;

  final restaurantResults = <Restaurant>[].obs;
  final itemResults = <SearchItemResult>[].obs;

  // Cached pool of every menu item across the nearby restaurants, each tagged
  // with its owning restaurant. Built lazily from the home feed.
  final List<SearchItemResult> _itemPool = [];
  bool _indexed = false;

  @override
  void onInit() {
    super.onInit();
    // Pre-build the index from whatever the home feed already has.
    ensureIndex();
  }

  /// Build (once) the searchable pool of items belonging to the nearby
  /// restaurants. The menu is per-restaurant, so we fetch each restaurant's
  /// menu by its restaurantId and tag every item with that restaurant.
  Future<void> ensureIndex({bool force = false}) async {
    if (isIndexing.value) return;
    if (_indexed && !force) return;
    isIndexing.value = true;
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
      // Re-run the current query against the freshly built pool.
      if (query.value.isNotEmpty) _applyFilter(query.value);
    } finally {
      isIndexing.value = false;
    }
  }

  /// Run a search over the nearby restaurants and their items.
  void search(String term) {
    final trimmed = term.trim();
    query.value = trimmed;
    if (trimmed.isEmpty) {
      restaurantResults.clear();
      itemResults.clear();
      hasSearched.value = false;
      return;
    }
    hasSearched.value = true;
    _applyFilter(trimmed);
    // Make sure items are indexed (no-op if already done). When indexing
    // finishes it re-applies the current query.
    ensureIndex();
  }

  void _applyFilter(String term) {
    final q = term.toLowerCase();
    restaurantResults.value = _home.restaurants
        .where((r) => r.name.toLowerCase().contains(q))
        .toList();
    itemResults.value = _itemPool
        .where((e) =>
            e.item.name.toLowerCase().contains(q) ||
            e.item.category.toLowerCase().contains(q) ||
            e.restaurant.name.toLowerCase().contains(q))
        .toList();
  }

  bool get hasResults =>
      restaurantResults.isNotEmpty || itemResults.isNotEmpty;

  void clear() {
    query.value = '';
    hasSearched.value = false;
    restaurantResults.clear();
    itemResults.clear();
  }
}
