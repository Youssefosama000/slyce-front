import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:slyce/core/network/api_exceptions.dart';
import 'package:slyce/core/storage/secure_storage.dart';
import 'package:slyce/features/auth/controllers/auth_controller.dart';
import 'package:slyce/features/home/models/menu_item.dart';
import 'package:slyce/features/home/models/restaurant.dart';
import 'package:slyce/features/home/repositories/menu_repository.dart';
import 'package:slyce/features/home/repositories/recommend_repository.dart';
import 'package:slyce/features/profile/controllers/address_controller.dart';
import 'package:slyce/features/profile/models/address_model.dart';
import 'package:slyce/features/profile/repositories/profile_repository.dart';

/// GetX controller for the home screen data.
///
/// All data is API-driven. There are no hard-coded restaurants, coordinates,
/// categories, or fallback search terms: the feed reflects exactly what the
/// backend returns for the customer's saved location.
class HomeController extends GetxController {
  final _menuRepo = MenuRepository();
  final _recommendRepo = RecommendRepository();
  final _profileRepo = ProfileRepository();

  // ── Observables ────────────────────────────────────────
  final isLoading = false.obs;
  final errorMessage = ''.obs;
  final restaurants = <Restaurant>[].obs;
  // Human-readable reason the restaurants list is empty (e.g. an HTTP error or
  // a missing delivery address). Surfaced in the home empty state.
  final restaurantsError = ''.obs;
  final recommended = <MenuItem>[].obs;
  // True while POST /recommend (+ enrichment) is in flight, so the home screen
  // can show a loader in the Recommended row instead of feed meals.
  final isLoadingRecommended = false.obs;
  // Owning restaurant (with its orderable branch) for each recommended meal,
  // keyed by mealId. POST /recommend doesn't carry restaurant/branch info, and
  // the home feed's restaurant usually isn't the one a recommended meal belongs
  // to, so ordering against it makes the cart API reject the add with
  // "Meal '<id>' does not belong to the restaurant". Resolved during enrichment.
  final _recommendedOwners = <String, Restaurant>{};
  final allMeals = <MenuItem>[].obs;

  // Id of the restaurant whose menu populated [allMeals]/[recommended]. Lets
  // other screens (e.g. the subscribe meal picker) reuse the already-fetched
  // menu instead of re-requesting it (avoids a slow duplicate menu fetch).
  final feedMealsRestaurantId = ''.obs;

  // Guards against redundant feed reloads. The address worker can fire multiple
  // times for the same selection (e.g. after loadAddresses()), which would
  // otherwise restart the whole feed and make the Recommended row flicker.
  String? _loadedForAddressId;
  bool _loadInFlight = false;
  bool _reloadQueued = false;

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

  /// A blank, data-less restaurant used as a safe placeholder so a recommended
  /// meal whose owner we couldn't resolve never orders against the wrong
  /// branch. The detail screen then resolves the branch from the meal itself.
  Restaurant get _emptyRestaurant => const Restaurant(
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

  /// The restaurant (with its orderable branch) that owns a recommended meal.
  /// Falls back to a blank placeholder when unknown, so add-to-cart never sends
  /// the home feed's wrong branch.
  Restaurant recommendedOwner(String mealId) =>
      _recommendedOwners[mealId] ?? _emptyRestaurant;

  @override
  void onInit() {
    super.onInit();
    // Keep the feed in sync with the selected delivery address. Selecting a
    // different address, adding the first address, or deleting addresses (which
    // can reset the selection to another address or to null) all re-run the
    // feed, so a stale location label and stale restaurants never linger.
    final addressCtrl = Get.find<AddressController>();
    ever<AddressModel?>(addressCtrl.selectedAddress, (addr) {
      // Only reload when the delivery address actually changes. The address
      // controller can re-emit the same selection (e.g. after loadAddresses(),
      // which _recommendCoords() calls during a load); reloading on those would
      // restart the feed and make the Recommended row flicker (clear → reload).
      if (addr?.id == _loadedForAddressId) return;
      loadData();
    });
    loadData();
  }

  Future<void> loadData() async {
    // Collapse overlapping reloads: if a load is already running, flag a pending
    // reload and let the current run pick it up when it finishes, instead of
    // clearing and rebuilding the Recommended row several times in a row.
    if (_loadInFlight) {
      _reloadQueued = true;
      return;
    }
    _loadInFlight = true;
    try {
      do {
        _reloadQueued = false;
        _loadedForAddressId =
            Get.find<AddressController>().selectedAddress.value?.id;
        isLoading.value = true;
        errorMessage.value = '';
        // Only show the Recommended loader when nothing is on screen yet. Keep
        // the current/cached row visible while refreshing so it doesn't blank
        // out and re-appear.
        isLoadingRecommended.value = recommended.isEmpty;
        try {
          // The "Recommended for your plan" row comes ONLY from POST /recommend,
          // so run it concurrently with the restaurant feed instead of after it.
          // That way the recommendations don't wait for the whole feed to
          // finish, and feed meals are never shown as a stand-in in Recommended.
          await Future.wait([
            _fetchData(),
            _loadRecommendations(),
          ]);
        } finally {
          isLoading.value = false;
        }
        // If the address changed mid-load, loop once more for the new location.
      } while (_reloadQueued);
    } finally {
      _loadInFlight = false;
    }
  }

  /// Populate [recommended] from the AI recommendation endpoint, using the
  /// signed-in customer's profile. Falls back silently to whatever the menu
  /// feed already provided if the request fails or returns nothing.
  Future<void> _loadRecommendations() async {
    try {
      final user = Get.find<AuthController>().currentUser.value;

      final storedId = await SecureStorage.instance.getCustomerId();
      final userId = (user?.id != null && user!.id!.isNotEmpty)
          ? user.id!
          : (storedId ?? '');
      if (userId.isEmpty) return;

      // Show cached recommendations instantly while fresh ones load, so the row
      // appears immediately on entry instead of only after the network round
      // trips. The fresh results below replace these.
      if (recommended.isEmpty) {
        final cached = await _readRecommendedCache(userId);
        if (cached.isNotEmpty) {
          recommended.value = cached;
          isLoadingRecommended.value = false;
        }
      }

      final store = SecureStorage.instance;

      // Most recent logged weight from history; fall back to the weight the
      // customer entered during onboarding (saved locally).
      double weight = 0;
      try {
        final history = await _profileRepo.getWeightHistory();
        if (history.isNotEmpty) {
          history.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
          weight = history.first.weightKg;
        }
      } catch (_) {
        // Weight history is optional — proceed without it.
      }
      if (weight == 0) {
        weight = await store.getProfileWeightKg() ?? 0;
      }

      // Height, gender, activity, allergens and diet preferences are captured
      // during onboarding right after sign up. The customer API exposes no
      // profile-read endpoint, so we persist them locally at onboarding and
      // read them back here to build the recommendation payload.
      final height = await store.getProfileHeightCm() ?? 0;
      final gender = (await store.getProfileGender()) ?? user?.gender ?? '';
      final activity =
          (await store.getProfileActivityRate()) ?? user?.activityLevel ?? '';
      final birthDay = (await store.getProfileBirthDay()) ?? user?.birthDay;
      final allergies = await store.getProfileAllergies();
      final dietPrefs = await store.getProfileDietPreferences();

      final profile = <String, dynamic>{
        'weight': weight,
        'height': height,
        'age': _ageFromBirthday(birthDay),
        'gender': gender,
        'activity_level': activity,
        'goal': '',
        'diet': '',
        'allergies': allergies,
        'diet_preferences': dietPrefs,
      };

      final items = await _recommendRepo.getRecommendations(
        userId: userId,
        profile: profile,
        topN: 6,
      );
      // The AI recommender keeps its own meal dataset, which can lag behind the
      // live catalogue: it may still recommend meals that were removed. Those
      // would otherwise linger in "Recommended" even though search and the
      // restaurant menu no longer list them. Validate each recommended meal
      // against the live backend and drop the ones that no longer exist.
      final ownerHints =
          Map<String, String>.from(_recommendRepo.lastRestaurantByMeal);
      final live = await _enrichRecommended(items, ownerHints);
      if (live.isNotEmpty) {
        // Cap the row at 6 meals.
        recommended.value = live.take(6).toList();
        // Persist for an instant render on the next open.
        await _writeRecommendedCache(userId, recommended);
      }
    } catch (_) {
      // On failure, leave Recommended empty rather than showing feed meals.
    } finally {
      isLoadingRecommended.value = false;
    }
  }

  /// Enrich recommended meals (which arrive from POST /recommend as id + name
  /// only) with their live image/price/sizes, drop any that no longer exist,
  /// and record the restaurant + orderable branch that owns each one so it can
  /// be added to the cart and ordered correctly.
  Future<List<MenuItem>> _enrichRecommended(
    List<MenuItem> items,
    Map<String, String> ownerHints,
  ) async {
    _recommendedOwners.clear();
    if (items.isEmpty) return items;

    // 1. Resolve each meal from GET /meals/:id: enrich the card AND note the
    //    meal's own restaurant id when the endpoint provides it. A 404 means
    //    the meal was removed, so it's dropped.
    final ridByItem = <String, String>{};
    final nameByRid = <String, String>{};
    final results = await Future.wait(
      items.map((item) async {
        if (item.id.isEmpty) return null;
        try {
          final meal = await _menuRepo.getMealById(item.id);
          final enriched = meal.toMenuItem();
          final rid = meal.restaurantId;
          if (rid != null && rid.isNotEmpty) {
            ridByItem[item.id] = rid;
            if (meal.restaurantName != null &&
                meal.restaurantName!.isNotEmpty) {
              nameByRid[rid] = meal.restaurantName!;
            }
          }
          return enriched.id.isNotEmpty ? enriched : item;
        } on ApiException catch (e) {
          return e.statusCode == 404 ? null : item;
        } catch (_) {
          return item;
        }
      }),
    );
    final live = results.whereType<MenuItem>().toList();

    // Publish the cards immediately. Owner/branch resolution below is only
    // needed for ordering (add-to-cart), so run it in the background instead of
    // making the Recommended row wait for those extra network round-trips.
    if (live.isNotEmpty) {
      recommended.value = live.take(6).toList();
    }
    isLoadingRecommended.value = false;
    unawaited(
      _resolveRecommendedOwners(live, ridByItem, nameByRid, ownerHints),
    );
    return live;
  }

  /// Resolve and cache the restaurant + orderable branch that owns each
  /// recommended meal so add-to-cart sends the correct branch. Runs in the
  /// background after the cards are shown; any meal left unresolved opens with
  /// a blank placeholder.
  Future<void> _resolveRecommendedOwners(
    List<MenuItem> live,
    Map<String, String> ridByItem,
    Map<String, String> nameByRid,
    Map<String, String> ownerHints,
  ) async {
    // 1a. The recommender now returns each meal's restaurant_id directly. Since
    //     GET /meals/:id carries no restaurant/branch, this is the most
    //     reliable owner hint, so seed it for branch resolution below.
    final liveIds = live.map((it) => it.id).toSet();
    ownerHints.forEach((mealId, rid) {
      if (rid.isNotEmpty && liveIds.contains(mealId)) {
        ridByItem.putIfAbsent(mealId, () => rid);
      }
    });
    if (kDebugMode) {
      debugPrint('[REC] live ids: $liveIds');
      debugPrint('[REC] ownerHints (mealId->restaurantId): $ownerHints');
      debugPrint('[REC] ridByItem after seed: $ridByItem');
    }

    // 1b. For meals whose detail endpoint exposed a restaurant, resolve the
    //     orderable branch from that restaurant's MENU (getMenu) — the branch
    //     the cart validates against. Trusting a stale/blank branch id makes
    //     the backend reject the add with "does not belong to the restaurant".
    final uniqueRids = ridByItem.values.toSet();
    if (uniqueRids.isNotEmpty) {
      final ownerEntries = await Future.wait(
        uniqueRids.map((rid) async {
          try {
            final resp = await _menuRepo.getMenu(rid);
            final branch = (resp.defaultBranchId != null &&
                    resp.defaultBranchId!.isNotEmpty)
                ? resp.defaultBranchId!
                : (resp.branches.isNotEmpty ? resp.branches.first.id : '');
            if (kDebugMode) {
              debugPrint('[REC] getMenu($rid) -> defaultBranchId='
                  '${resp.defaultBranchId}, branches=${resp.branches.length}, '
                  'chosenBranch=$branch');
            }
            if (branch.isEmpty) return MapEntry<String, Restaurant?>(rid, null);
            return MapEntry<String, Restaurant?>(
              rid,
              Restaurant(
                id: rid,
                name: nameByRid[rid] ?? resp.restaurantName ?? 'Restaurant',
                bannerUrl: '',
                logoUrl: '',
                location: '',
                phone: '',
                rating: 0,
                openingHours: const [],
                menu: const [],
                categories: const [],
                branches: resp.branches,
                defaultBranchId: branch,
              ),
            );
          } catch (_) {
            return MapEntry<String, Restaurant?>(rid, null);
          }
        }),
      );
      final ownerByRid = <String, Restaurant>{};
      for (final e in ownerEntries) {
        final owner = e.value;
        if (owner != null) ownerByRid[e.key] = owner;
      }
      ridByItem.forEach((itemId, rid) {
        final owner = ownerByRid[rid];
        if (owner != null) _recommendedOwners[itemId] = owner;
      });
      if (kDebugMode) {
        debugPrint('[REC] resolved via restaurant_id (step1b): '
            '${_recommendedOwners.map((k, v) => MapEntry(k, v.primaryBranchId))}');
      }
    }

    // 1c. GET /meals/:id carries NO restaurant/branch, so for anything still
    //     unresolved, look the meal up in the nearby meal index
    //     (/meals/nearby) by name. Each hit carries its OWN restaurantId +
    //     branchId — the same authoritative pairing the search screen orders
    //     from. We only accept an exact meal-id match; pairing a meal with a
    //     different restaurant's branch is what triggers the cart's
    //     "does not belong to the restaurant" rejection.
    final unresolvedItems = live
        .where(
            (it) => it.id.isNotEmpty && !_recommendedOwners.containsKey(it.id))
        .toList();
    if (kDebugMode) {
      debugPrint('[REC] unresolved after step1b: '
          '${unresolvedItems.map((it) => it.id).toList()}');
    }
    if (unresolvedItems.isNotEmpty) {
      final coords = await _recommendCoords();
      if (kDebugMode) debugPrint('[REC] coords for nearby fallback: $coords');
      if (coords != null) {
        await Future.wait(
          unresolvedItems.map((it) async {
            try {
              final hits = await _menuRepo.searchMealsNearby(
                term: it.name,
                latitude: coords.lat,
                longitude: coords.lng,
              );
              final matches = hits.where((h) => h.id == it.id).toList();
              if (matches.isEmpty) return;
              final match = matches.first;
              final rid = match.restaurantId;
              final bid = match.branchId;
              if (rid != null &&
                  rid.isNotEmpty &&
                  bid != null &&
                  bid.isNotEmpty) {
                _recommendedOwners[it.id] = Restaurant(
                  id: rid,
                  name: (match.restaurantName != null &&
                          match.restaurantName!.isNotEmpty)
                      ? match.restaurantName!
                      : 'Restaurant',
                  bannerUrl: '',
                  logoUrl: '',
                  location: '',
                  phone: '',
                  rating: 0,
                  openingHours: const [],
                  menu: const [],
                  categories: const [],
                  defaultBranchId: bid,
                );
              }
            } catch (_) {
              // Skip; the nearby-menu scan below is the next fallback.
            }
          }),
        );
      }
    }

    // 2. For meals whose detail endpoint didn't expose a restaurant/branch,
    //    match them against the customer's nearby restaurants' menus. Each
    //    nearby restaurant carries its orderable branch, so a match yields a
    //    restaurant the detail screen can actually order from. (This mirrors
    //    how search resolves a meal's owner.)
    final unresolved = live
        .where(
            (it) => it.id.isNotEmpty && !_recommendedOwners.containsKey(it.id))
        .map((it) => it.id)
        .toSet();
    if (unresolved.isNotEmpty) {
      try {
        final coords = await _recommendCoords();
        if (coords != null) {
          final restaurants = await _menuRepo.getTopRatedRestaurantsNearby(
            latitude: coords.lat,
            longitude: coords.lng,
          );
          if (kDebugMode) {
            debugPrint('[REC] step2 nearby restaurants: '
                '${restaurants.map((r) => r.id).toList()}');
          }
          await Future.wait(
            restaurants.map((r) async {
              if (r.id.isEmpty) return;
              try {
                final resp = await _menuRepo.getMenu(r.id);
                // Order against the branch the MENU is served from, not the
                // nearby card's branch, so the cart accepts the meal.
                final menuBranch = (resp.defaultBranchId != null &&
                        resp.defaultBranchId!.isNotEmpty)
                    ? resp.defaultBranchId!
                    : (resp.branches.isNotEmpty
                        ? resp.branches.first.id
                        : '');
                final owner = Restaurant(
                  id: r.id,
                  name: r.name,
                  bannerUrl: r.bannerUrl,
                  logoUrl: r.logoUrl,
                  location: r.location,
                  phone: r.phone,
                  rating: r.rating,
                  openingHours: r.openingHours,
                  menu: const [],
                  categories: r.categories,
                  branches:
                      resp.branches.isNotEmpty ? resp.branches : r.branches,
                  defaultBranchId:
                      menuBranch.isNotEmpty ? menuBranch : r.defaultBranchId,
                );
                for (final m in resp.allMeals) {
                  if (unresolved.contains(m.id) &&
                      !_recommendedOwners.containsKey(m.id)) {
                    _recommendedOwners[m.id] = owner;
                  }
                }
              } catch (_) {
                // Skip this restaurant.
              }
            }),
          );
        }
      } catch (_) {
        // Best-effort: any meal left unresolved opens with a blank placeholder.
      }
    }
  }

  // ── Recommended cache (instant display on next open) ────────────────

  /// Read the cached recommended meals for [userId]. Returns an empty list when
  /// there is no cache, it belongs to a different customer, or it is corrupt.
  Future<List<MenuItem>> _readRecommendedCache(String userId) async {
    try {
      final raw = await SecureStorage.instance.getRecommendedCache();
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const [];
      // Only reuse the cache when it belongs to the signed-in customer.
      if (decoded['userId'] != userId) return const [];
      final meals = decoded['meals'];
      if (meals is! List) return const [];
      return meals
          .whereType<Map>()
          .map((m) => MenuItem(
                id: (m['id'] ?? '').toString(),
                name: (m['name'] ?? '').toString(),
                description: (m['description'] ?? '').toString(),
                price: (m['price'] as num?)?.toDouble() ?? 0,
                imageUrl: (m['imageUrl'] ?? '').toString(),
                category: (m['category'] ?? '').toString(),
                nutrition: NutritionInfo(
                  calories: (m['calories'] as num?)?.toInt() ?? 0,
                  protein: (m['protein'] as num?)?.toDouble() ?? 0,
                  fats: (m['fats'] as num?)?.toDouble() ?? 0,
                  carbs: (m['carbs'] as num?)?.toDouble() ?? 0,
                ),
              ))
          .where((m) => m.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Persist [meals] (display fields only) for [userId] so the Recommended row
  /// can render instantly on the next open. Best-effort; failures are ignored.
  Future<void> _writeRecommendedCache(
    String userId,
    List<MenuItem> meals,
  ) async {
    try {
      final payload = {
        'userId': userId,
        'meals': meals
            .map((m) => {
                  'id': m.id,
                  'name': m.name,
                  'description': m.description,
                  'price': m.price,
                  'imageUrl': m.imageUrl,
                  'category': m.category,
                  'calories': m.nutrition.calories,
                  'protein': m.nutrition.protein,
                  'fats': m.nutrition.fats,
                  'carbs': m.nutrition.carbs,
                })
            .toList(),
      };
      await SecureStorage.instance.setRecommendedCache(jsonEncode(payload));
    } catch (_) {
      // Caching is best-effort.
    }
  }

  /// Resolve the customer's delivery coordinates (selected address first, then
  /// the first saved address that has coordinates). Returns null when none.
  Future<({double lat, double lng})?> _recommendCoords() async {
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
      // No address available.
    }
    return null;
  }

  /// Keep only the recommended meals that still exist in the live catalogue.
  ///
  /// Each meal is verified with GET /v1/meals/:id. A 404 means the meal was
  /// removed, so it is dropped. On any other error (network/timeout/5xx) the
  /// meal is kept, so a transient failure never wrongly empties the feed.
  /// Checks run in parallel to keep the home load fast.
  Future<List<MenuItem>> _filterToLiveMeals(List<MenuItem> items) async {
    if (items.isEmpty) return items;
    final checks = await Future.wait(
      items.map((item) async {
        if (item.id.isEmpty) return null;
        try {
          // /recommend returns only meal_id + name, so enrich each entry with
          // the live meal's image, price, sizes and macros so the Recommended
          // cards render fully. Doubles as the existence check: a 404 here
          // means the meal was removed and the entry is dropped below.
          final full = (await _menuRepo.getMealById(item.id)).toMenuItem();
          return full.id.isNotEmpty ? full : item;
        } on ApiException catch (e) {
          // Drop only when the meal is definitively gone.
          return e.statusCode == 404 ? null : item;
        } catch (_) {
          // Unknown error — keep the item rather than hide a valid meal.
          return item;
        }
      }),
    );
    return checks.whereType<MenuItem>().toList();
  }

  /// Best-effort age (in years) derived from a stored birthday string.
  int _ageFromBirthday(String? birthDay) {
    if (birthDay == null || birthDay.isEmpty) return 0;
    final dob = DateTime.tryParse(birthDay);
    if (dob == null) return 0;
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  Future<void> _fetchData() async {
    // Reset the feed up-front so data from a previous location is never shown
    // when the new location returns nothing (empty `nearby` or empty menu), or
    // when there is no longer any saved delivery address at all.
    restaurantsError.value = '';
    errorMessage.value = '';
    restaurants.clear();
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
          // A restaurant's menu endpoint can lag behind deletions and still
          // list removed meals (GET /v1/meals/:id returns 404 for them). Drop
          // those so the feed fallback never seeds "Recommended"/the meal
          // picker with meals that no longer exist. If everything in this
          // restaurant's menu is stale, fall through to the next restaurant.
          final live = await _filterToLiveMeals(items);
          if (live.isNotEmpty) {
            allMeals.value = live;
            feedMealsRestaurantId.value = id;
            errorMessage.value = '';
            return;
          }
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
