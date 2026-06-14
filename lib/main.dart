import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/core/constants/api_endpoints.dart';
import 'package:slyce/core/network/dio_client.dart';
import 'package:slyce/core/storage/secure_storage.dart';
import 'package:slyce/core/bindings/initial_binding.dart';

// Features
import 'package:slyce/features/auth/screens/sign_in_screen.dart';
import 'package:slyce/features/auth/screens/sign_up_screen.dart';
import 'package:slyce/features/onboarding/screens/gender_screen.dart';
import 'package:slyce/features/onboarding/screens/weight_screen.dart';
import 'package:slyce/features/onboarding/screens/height_screen.dart';
import 'package:slyce/features/onboarding/screens/activity_screen.dart';
import 'package:slyce/features/onboarding/screens/allergies_screen.dart';
import 'package:slyce/features/onboarding/screens/food_preferences_screen.dart';
import 'package:slyce/features/onboarding/screens/plan_screen.dart';
import 'package:slyce/features/home/screens/main_scaffold.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Dio client with the API base URL
  DioClient.instance.init(baseUrl: ApiEndpoints.baseUrl);

  // Stay signed in across app restarts: if a valid access token is already
  // stored, skip the sign-in screen and open the app straight on home.
  final loggedIn = await SecureStorage.instance.isLoggedIn();

  runApp(SlyceApp(initialRoute: loggedIn ? '/home' : '/sign-in'));
}

class SlyceApp extends StatelessWidget {
  final String initialRoute;
  const SlyceApp({super.key, this.initialRoute = '/sign-in'});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Slyce',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      initialBinding: InitialBinding(),
      initialRoute: initialRoute,
      getPages: [
        // ── Mobile (customer app) ──────────────────────────────
        GetPage(name: '/sign-in', page: () => const SignInScreen()),
        GetPage(name: '/sign-up', page: () => const SignUpScreen()),
        GetPage(name: '/gender', page: () => const GenderScreen()),
        GetPage(name: '/weight', page: () => const WeightScreen()),
        GetPage(name: '/height', page: () => const HeightScreen()),
        GetPage(name: '/activity', page: () => const ActivityScreen()),
        GetPage(name: '/allergies', page: () => const AllergiesScreen()),
        GetPage(name: '/food-preferences', page: () => const FoodPreferencesScreen()),
        GetPage(name: '/plan', page: () => const PlanScreen()),
        GetPage(name: '/home', page: () => const MainScaffold()),
      ],
    );
  }
}

