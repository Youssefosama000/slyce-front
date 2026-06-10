import 'package:get/get.dart';
import 'package:slyce/core/network/api_exceptions.dart';
import 'package:flutter/widgets.dart';
import 'package:slyce/features/subscribe/models/subscription_model.dart';
import 'package:slyce/features/subscribe/repositories/subscription_repository.dart';
import 'package:slyce/features/home/models/restaurant.dart';
import 'package:slyce/features/home/models/menu_item.dart';
import 'package:slyce/features/home/repositories/menu_repository.dart';
import 'package:slyce/features/home/controllers/home_controller.dart';

/// GetX controller for meal subscription management.
class SubscribeController extends GetxController {
  final _subRepo = SubscriptionRepository();
  final _menuRepo = MenuRepository();

  // ── Observables ─────────────────────────────────────────────────────
  final isLoading = false.obs;
  final isLoadingSubscriptions = false.obs;
  final errorMessage = ''.obs;
  final subscriptions = <SubscriptionModel>[].obs;
  final isWeekly = true.obs;
  // No days pre-selected on open — the customer chooses their own.
  final selectedDays = <String>{}.obs;
  final selectedTimeSlot = 'Morning'.obs;
  final startDate = Rxn<DateTime>();
  final selectedMealSizes = <Map<String, dynamic>>[].obs;

  // Branches available for the selected restaurant + the chosen branch id
  // (resolved internally; the subscription API needs a branchId).
  final branches = <Branch>[].obs;
  final selectedBranchId = RxnString();

  // Nearby restaurants (from the home feed) the customer can subscribe to, and
  // the chosen restaurant id. Selecting one loads its branch + full menu.
  final restaurants = <Restaurant>[].obs;
  final selectedRestaurantId = RxnString();

  // Meals available for the selected branch's menu (drives the meal picker).
  final meals = <MenuItem>[].obs;
  final isLoadingMeals = false.obs;

  // Time slot options from the API description
  static const timeSlots = [
    'EarlyMorning',
    'Morning',
    'Afternoon',
    'LateAfternoon',
    'Evening',
    'Night',
  ];

  static const timeSlotLabels = {
    'EarlyMorning': '6:00 – 9:00',
    'Morning': '9:00 – 12:00',
    'Afternoon': '12:00 – 15:00',
    'LateAfternoon': '15:00 – 18:00',
    'Evening': '18:00 – 21:00',
    'Night': '21:00 – 00:00',
  };

  void toggleDay(String day) {
    if (selectedDays.contains(day)) {
      selectedDays.remove(day);
    } else {
      selectedDays.add(day);
    }
  }

  /// Populate the available branches for the current restaurant and pick a
  /// sensible default selection.
  void setBranches(List<Branch> branchList, {String? defaultId}) {
    branches.assignAll(branchList);
    final current = selectedBranchId.value;
    final stillValid =
        current != null && branchList.any((b) => b.id == current);
    if (!stillValid) {
      selectedBranchId.value =
          defaultId ?? (branchList.isNotEmpty ? branchList.first.id : null);
    }
  }

  /// Resolve branches for [restaurant]. Uses the embedded branch list when
  /// present, otherwise fetches the default branch's details from the API
  /// (GET /branches/:id/details) so the subscription has a valid branch id.
  Future<void> loadBranchesForRestaurant(Restaurant restaurant) async {
    setBranches(restaurant.branches, defaultId: restaurant.primaryBranchId);
    if (branches.isNotEmpty) return;

    final branchId = restaurant.primaryBranchId;
    if (branchId == null || branchId.isEmpty) return;
    try {
      final branch = await _menuRepo.getBranchDetails(branchId);
      branches.assignAll([branch]);
      selectedBranchId.value = branch.id.isNotEmpty ? branch.id : branchId;
    } catch (_) {
      // Branch details unavailable — keep the resolved default id, if any.
    }
  }

  /// Load the meals shown in the subscription picker from the restaurant's menu.
  ///
  /// The menu is per-RESTAURANT (one menu per restaurant) and is fetched with
  /// the restaurantId — `restaurant.id` resolves to the restaurantId. Ordering
  /// (the subscription itself), by contrast, uses the nearby branchId. No
  /// hard-coded fallback: if nothing loads, the picker stays empty.
  Future<void> loadMealsForRestaurant(Restaurant restaurant) async {
    // Use the embedded menu when the restaurant already carries one.
    if (restaurant.menu.isNotEmpty) {
      meals.assignAll(restaurant.menu);
      return;
    }
    final restaurantId = restaurant.id;
    if (restaurantId.isEmpty) return;

    isLoadingMeals.value = true;
    try {
      final response = await _menuRepo.getMenu(restaurantId);
      meals.assignAll(
        response.allMeals.map((m) => m.toMenuItem()).toList(),
      );
    } on ApiException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      // Leave meals empty (no hard-coded fallback).
    } finally {
      isLoadingMeals.value = false;
    }
  }

  bool _boundToHome = false;

  /// Bind the subscription meal picker to the home feed. The home feed loads
  /// restaurants + their menu asynchronously, so reading it once in initState
  /// often finds nothing. We apply it now and react to later updates.
  void bindToHome(HomeController home) {
    if (!_boundToHome) {
      _boundToHome = true;
      ever<List<MenuItem>>(home.allMeals, (_) => _applyHome(home));
      ever<List<Restaurant>>(home.restaurants, (_) => _applyHome(home));
    }
    // Defer the first apply out of the build phase. bindToHome is called from
    // initState; mutating the observable lists synchronously there triggers
    // "setState() called during build". The ever() listeners above handle
    // later updates safely (they fire outside the build phase).
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyHome(home));
  }

  void _applyHome(HomeController home) {
    // Mirror the nearby restaurants into the picker so the customer can choose
    // which available restaurant (near their delivery address) to subscribe to.
    restaurants.assignAll(home.restaurants);
    if (home.restaurants.isEmpty) return;

    // The home feed already fetched the full menu for one nearby restaurant
    // into `allMeals`. Prefer that restaurant on first open and reuse those
    // meals so the picker shows instantly instead of refetching the menu.
    final preferredId = home.feedMealsRestaurantId.value;
    final hasPreloaded = preferredId.isNotEmpty &&
        home.allMeals.isNotEmpty &&
        home.restaurants.any((r) => r.id == preferredId);

    final current = selectedRestaurantId.value;
    final stillValid =
        current != null && home.restaurants.any((r) => r.id == current);

    if (!stillValid) {
      if (hasPreloaded) {
        selectRestaurant(preferredId, preloadedMeals: home.allMeals);
      } else {
        selectRestaurant(home.restaurants.first.id);
      }
      return;
    }

    // Selection still valid: if it's the preloaded restaurant but the picker is
    // still empty (a refetch was pending), reuse the home feed's meals.
    if (hasPreloaded && current == preferredId && meals.isEmpty) {
      meals.assignAll(home.allMeals);
    }
  }

  /// Initialise the subscription flow for ONE specific restaurant (opened from
  /// the restaurant page's "Subscribe" button). There is no restaurant picker
  /// anymore — the subscription is always tied to the restaurant the customer
  /// came from. Resolves its branch (for the subscription's branchId) and
  /// loads its full menu via the same meals endpoints used elsewhere.
  void initForRestaurant(Restaurant restaurant) {
    restaurants.assignAll([restaurant]);
    selectedRestaurantId.value = restaurant.id;
    selectedMealSizes.clear();
    meals.clear();
    branches.clear();
    selectedBranchId.value = null;
    loadBranchesForRestaurant(restaurant);
    loadMealsForRestaurant(restaurant);
  }

  /// Switch the subscription to a different nearby restaurant: resolve its
  /// branch (for the subscription's branchId) and load its full menu. Clears
  /// previously picked meals since they belong to the old restaurant's menu.
  void selectRestaurant(String restaurantId, {List<MenuItem>? preloadedMeals}) {
    Restaurant? restaurant;
    for (final r in restaurants) {
      if (r.id == restaurantId) {
        restaurant = r;
        break;
      }
    }
    if (restaurant == null) return;
    selectedRestaurantId.value = restaurantId;
    selectedMealSizes.clear();
    meals.clear();
    loadBranchesForRestaurant(restaurant);
    // Reuse the menu the home feed already fetched for this restaurant when
    // available — avoids a slow duplicate `GET /restaurants/:id/menu` call.
    if (preloadedMeals != null && preloadedMeals.isNotEmpty) {
      meals.assignAll(preloadedMeals);
    } else {
      loadMealsForRestaurant(restaurant);
    }
  }

  /// Add (or replace) the chosen size for a meal in the subscription.
  ///
  /// Only ONE size per meal can be in the subscription at a time, so any
  /// previously chosen size for the same meal is swapped out. Display-only
  /// fields (mealId/name/size/price) are kept locally so the picker and the
  /// review UI can render the selection; the POST payload is rebuilt cleanly
  /// in [subscribe] with only the fields the API expects.
  void addMealSize(
    String mealSizeId,
    int quantity, {
    String? mealId,
    String? mealName,
    String? sizeName,
    double? price,
    String? imageUrl,
  }) {
    if (mealId != null) {
      selectedMealSizes.removeWhere((m) => m['mealId'] == mealId);
    }
    selectedMealSizes.add({
      'MealSizeId': mealSizeId,
      'quantity': quantity,
      if (mealId != null) 'mealId': mealId,
      if (mealName != null) 'mealName': mealName,
      if (sizeName != null) 'sizeName': sizeName,
      if (price != null) 'price': price,
      if (imageUrl != null) 'imageUrl': imageUrl,
    });
  }

  void removeMealSize(int index) {
    if (index >= 0 && index < selectedMealSizes.length) {
      selectedMealSizes.removeAt(index);
    }
  }

  /// Remove a selected meal-size by its id.
  void removeMealSizeById(String mealSizeId) {
    selectedMealSizes.removeWhere((m) => m['MealSizeId'] == mealSizeId);
  }

  /// Remove whatever size was selected for a given meal.
  void removeMealById(String mealId) {
    selectedMealSizes.removeWhere((m) => m['mealId'] == mealId);
  }

  /// Whether a given meal-size is currently in the subscription selection.
  bool isMealSizeSelected(String mealSizeId) =>
      selectedMealSizes.any((m) => m['MealSizeId'] == mealSizeId);

  /// The selection entry for a given meal (or null if the meal isn't added).
  Map<String, dynamic>? selectionForMeal(String mealId) {
    for (final m in selectedMealSizes) {
      if (m['mealId'] == mealId) return m;
    }
    return null;
  }

  /// Total number of meals currently added to the subscription.
  int get selectedMealCount => selectedMealSizes.length;

  /// Load all subscriptions from API.
  Future<void> loadSubscriptions() async {
    isLoadingSubscriptions.value = true;
    errorMessage.value = '';

    try {
      subscriptions.value = await _subRepo.getSubscriptions();
    } on ApiException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      subscriptions.value = [];
    } finally {
      isLoadingSubscriptions.value = false;
    }
  }

  /// Submit subscription to the API.
  Future<bool> subscribe({
    required String branchId,
    required String deliveryAddressId,
  }) async {
    if (startDate.value == null) {
      errorMessage.value = 'Please select a start date.';
      return false;
    }
    if (selectedDays.isEmpty) {
      errorMessage.value = 'Please select at least one delivery day.';
      return false;
    }
    if (selectedMealSizes.isEmpty) {
      errorMessage.value = 'Please add at least one meal to subscribe.';
      return false;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      await _subRepo.subscribe(
        branchId: branchId,
        deliveryAddressId: deliveryAddressId,
        timeSlot: selectedTimeSlot.value,
        deliveryDays: selectedDays.toList(),
        startDate: startDate.value!
            .toIso8601String()
            .split('T')
            .first,
        // Send only the fields the API expects, dropping the local
        // display-only metadata (mealId/name/size/price/imageUrl).
        subscriptionMeals: selectedMealSizes
            .map((m) => <String, dynamic>{
                  'MealSizeId': m['MealSizeId'],
                  'quantity': m['quantity'],
                })
            .toList(),
        billingCycle: isWeekly.value ? 'Weekly' : 'Monthly',
      );
      return true;
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (_) {
      errorMessage.value = 'Subscription failed. Please try again.';
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}


