import 'package:get/get.dart';

/// Holds the currently selected bottom-navigation tab so any screen can switch
/// tabs (e.g. the Cart's "Add Items" button jumps back to Home to browse).
class NavController extends GetxController {
  final currentIndex = 0.obs;

  static const int homeTab = 0;
  static const int subscribeTab = 1;
  static const int cartTab = 2;
  static const int profileTab = 3;

  void goToTab(int index) => currentIndex.value = index;
}
