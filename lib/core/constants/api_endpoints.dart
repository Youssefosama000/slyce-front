/// Centralized API endpoint constants derived from the Postman collection
/// (Slyce.json). Paths here mirror the latest API exactly (CUSTOMER scope).
///
/// Admin / restaurant-owner endpoints (restaurant applications, approve/reject,
/// add/activate branch, working hours, create category, add/remove meal or
/// size, update banner/logo, debug jobs) have been removed — this is a
/// customer-only app.
class ApiEndpoints {
  ApiEndpoints._();

  // ── Base URL ────────────────────────────────────────────────
  static const String baseUrl =
      'https://slyce-b2bmh0gzajd8fufu.westeurope-01.azurewebsites.net/api';
  static const String apiVersion = 'v1';

  // ── Identity / Auth ────────────────────────────────────────
  static const String login = '/$apiVersion/login';
  static const String setPassword = '/$apiVersion/auth/set-password';
  // TODO: confirm — not present in Slyce.json (customer scope). Kept only
  // because the existing "Forgot password" UI flow still calls it. Remove if
  // the backend does not support it.
  static const String forgotPassword = '/$apiVersion/auth/forgot-password';

  // ── Customers / Onboarding ──────────────────────────────────
  static const String register = '/$apiVersion/customers';
  // TODO: confirm — GET/PATCH /customers/me are not in Slyce.json. Used by the
  // profile screen. The collection only exposes the per-field profile PATCH
  // endpoints below. Remove if profile read/update is unsupported.
  static const String customerProfile = '/$apiVersion/customers/me';
  static const String updateGender =
      '/$apiVersion/customers/me/profile/gender';
  static const String updateActivityRate =
      '/$apiVersion/customers/me/profile/activity-rate';
  static const String updateHeight =
      '/$apiVersion/customers/me/profile/height';
  static const String updateWeight =
      '/$apiVersion/customers/me/profile/weight';
  static const String updateAllergens =
      '/$apiVersion/customers/me/profile/allergens';
  static const String updateDietPreferences =
      '/$apiVersion/customers/me/profile/diet-prefs';
  // TODO: confirm — not in Slyce.json. Used by the weight-history screen.
  static const String weightHistory =
      '/$apiVersion/customers/me/profile/weight-history';

  // ── Addresses ────────────────────────────────────────────
  static const String addresses = '/$apiVersion/addresses';
  static String addressById(String id) => '/$apiVersion/addresses/$id';

  // ── Cart ──────────────────────────────────────────────
  static const String cart = '/$apiVersion/cart';
  static const String checkout = '/$apiVersion/cart/checkout';
  // TODO: confirm — per-item cart routes are not in Slyce.json (the API only
  // supports add (POST), view (GET) and clear (DELETE) on /cart). Still used by
  // the cart screen's quantity +/- and per-row delete. Remove if unsupported.
  static String cartItem(String itemId) => '/$apiVersion/cart/$itemId';

  // ── Orders (customer-scoped, per Slyce.json) ──────────────────────────
  //   GET /v1/customers/:customerId/orders        -> orders history list
  //   GET /v1/customers/:customerId/orders/:id    -> single order details
  static String customerOrders(String customerId) =>
      '/$apiVersion/customers/$customerId/orders';
  static String customerOrderById(String customerId, String id) =>
      '/$apiVersion/customers/$customerId/orders/$id';

  // ── Menu / Meals (read-only, customer) ──────────────────────
  static String restaurantMenu(String restaurantId) =>
      '/$apiVersion/restaurants/$restaurantId/menu';
  static String mealById(String id) => '/$apiVersion/meals/$id';

  // ── Restaurants (read-only, customer) ───────────────────────
  static const String topRatedNearby =
      '/$apiVersion/restaurants/top-rated/nearby';
  static String branchDetails(String id) => '/$apiVersion/branches/$id/details';

  // ── Food / Lookups ───────────────────────────────────────
  static const String foodSearch = '/$apiVersion/food';
  static const String foodExternalSearch = '/$apiVersion/food/external';
  static const String foodAllergens = '/$apiVersion/food/allergens';
  static const String foodPreferences = '/$apiVersion/food/food-preferences';

  // ── Subscriptions ────────────────────────────────────────
  // Slyce.json exposes only two customer subscription endpoints:
  //   POST /v1/subscriptions                  -> create a meal subscription
  //   GET  /v1/subscriptions?Page=&PageSize=  -> customer subscriptions summary
  static const String subscriptions = '/$apiVersion/subscriptions';
}
