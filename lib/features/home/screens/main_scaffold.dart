import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/features/cart/controllers/cart_controller.dart';
import 'package:slyce/features/home/controllers/nav_controller.dart';
import 'package:slyce/features/home/screens/home_screen.dart';
import 'package:slyce/features/subscribe/screens/subscribe_screen.dart';
import 'package:slyce/features/cart/screens/cart_screen.dart';
import 'package:slyce/features/profile/screens/profile_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  final NavController _nav = Get.find<NavController>();

  // The "Subscribe" tab completes an in-progress subscription: the customer
  // picks meals from a restaurant's Subscribe page, then finishes here (billing
  // cycle, delivery, submit). With no restaurant arg, SubscribeScreen reuses the
  // controller's in-progress selection. "Your Subscriptions" lives in Profile.
  final List<Widget> _screens = const [
    HomeScreen(),
    SubscribeScreen(),
    CartScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(
        () => IndexedStack(
          index: _nav.currentIndex.value,
          children: _screens,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: kWhite,
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, -4),
            )
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Obx(() {
              final current = _nav.currentIndex.value;
              final count = Get.find<CartController>().totalItems;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.home_outlined,
                    label: 'Home',
                    selected: current == 0,
                    onTap: () => _nav.goToTab(0),
                  ),
                  _NavItem(
                    icon: Icons.autorenew,
                    label: 'Subscribe',
                    selected: current == 1,
                    onTap: () => _nav.goToTab(1),
                  ),
                  _NavItem(
                    icon: Icons.shopping_basket_outlined,
                    label: 'Cart',
                    selected: current == 2,
                    badge: count > 0 ? count : null,
                    onTap: () => _nav.goToTab(2),
                  ),
                  _NavItem(
                    icon: Icons.person_outline,
                    label: 'Profile',
                    selected: current == 3,
                    onTap: () => _nav.goToTab(3),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final int? badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: selected ? kPrimaryGreen : kGreyColor,
                  size: 26,
                ),
                if (badge != null)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: kPrimaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                          color: kWhite,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? kPrimaryGreen : kGreyColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


