import 'package:get/get.dart';
import 'package:slyce/features/auth/controllers/auth_controller.dart';
import 'package:slyce/features/home/controllers/home_controller.dart';
import 'package:slyce/features/home/controllers/nav_controller.dart';
import 'package:slyce/features/cart/controllers/cart_controller.dart';
import 'package:slyce/features/profile/controllers/address_controller.dart';
import 'package:slyce/features/onboarding/controllers/onboarding_controller.dart';
import 'package:slyce/features/subscribe/controllers/subscribe_controller.dart';
import 'package:slyce/features/search/controllers/search_controller.dart' as app;

/// Registers all lazy-loaded controllers at app startup.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Auth is always needed
    Get.lazyPut<AuthController>(() => AuthController(), fenix: true);

    // Onboarding
    Get.lazyPut<OnboardingController>(() => OnboardingController(), fenix: true);

    // Main app controllers
    Get.lazyPut<NavController>(() => NavController(), fenix: true);
    Get.lazyPut<HomeController>(() => HomeController(), fenix: true);
    Get.lazyPut<CartController>(() => CartController(), fenix: true);
    Get.lazyPut<AddressController>(() => AddressController(), fenix: true);
    Get.lazyPut<SubscribeController>(() => SubscribeController(), fenix: true);
    Get.lazyPut<app.SearchController>(() => app.SearchController(), fenix: true);
  }
}

