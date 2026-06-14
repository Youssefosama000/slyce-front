import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/features/auth/controllers/auth_controller.dart';
import 'package:slyce/features/profile/controllers/address_controller.dart';
import 'package:slyce/features/profile/screens/addresses_screen.dart';
import 'package:slyce/features/ai_chat/widgets/chatbot_sheet.dart';
import 'package:slyce/features/home/controllers/home_controller.dart';
import 'package:slyce/features/home/models/menu_item.dart';
import 'package:slyce/features/home/models/restaurant.dart';
import 'package:slyce/widgets/loading_widget.dart';
import 'package:slyce/widgets/error_widget.dart';
import 'package:slyce/features/home/screens/restaurant/restaurant_menu_screen.dart';
import 'package:slyce/features/home/screens/item/item_detail_screen.dart';
import 'package:slyce/features/search/screens/search_screen.dart';
import 'package:slyce/widgets/address_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final homeCtrl = Get.find<HomeController>();

    return Scaffold(
      backgroundColor: kBgColor,
      body: Obx(() {
        if (homeCtrl.isLoading.value && homeCtrl.restaurants.isEmpty) {
          return const SafeArea(
            child: SlyceLoadingWidget(),
          );
        }

        return RefreshIndicator(
          onRefresh: homeCtrl.refresh,
          color: kPrimaryGreen,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeaderPanel()),
              if (homeCtrl.errorMessage.value.isNotEmpty &&
                  homeCtrl.restaurants.isEmpty)
                SliverToBoxAdapter(
                  child: SlyceErrorWidget(
                    message: homeCtrl.errorMessage.value,
                    onRetry: homeCtrl.refresh,
                  ),
                )
              else ...[
                SliverToBoxAdapter(child: _buildRecommendedSection(homeCtrl)),
                SliverToBoxAdapter(child: _buildRestaurantsSection(homeCtrl)),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      }),
    );
  }

  // ── Green header panel (avatar + location + bell, greeting, search) ──
  Widget _buildHeaderPanel() {
    final auth = Get.find<AuthController>();
    final addressCtrl = Get.find<AddressController>();
    return Obx(() {
      final user = auth.currentUser.value;
      final name = user?.firstName ?? 'there';
      final initial = user?.initials ?? 'U';
      final address = addressCtrl.selectedAddress.value;
      final locationText =
          address?.area ?? address?.label ?? 'Set your location';

      return Container(
        padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
        decoration: const BoxDecoration(
          color: kPrimaryGreen,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: kWhite,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: kPrimaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showLocationPicker(
                      Get.find<AddressController>(),
                      Get.find<HomeController>(),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Delivery location',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: Colors.white70),
                            ),
                            const Icon(Icons.keyboard_arrow_down,
                                size: 16, color: kWhite),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          locationText,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: kWhite,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _showChatbot,
                  child: Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                      color: kWhite,
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/icons/chat_bot_black.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Hello $name',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: kWhite,
              ),
            ),
            const SizedBox(height: 16),
            _buildSearchBar(),
          ],
        ),
      );
    });
  }

  /// Opens the Slyce AI chat bottom sheet.
  void _showChatbot() {
    showModalBottomSheet(
      context: Get.context!,
      isScrollControlled: true,
      backgroundColor: kBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ChatbotSheet(),
    );
  }

  void _showLocationPicker(
    AddressController addressCtrl,
    HomeController homeCtrl,
  ) {
    showModalBottomSheet(
      context: Get.context!,
      backgroundColor: kBgColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(ctx).padding.bottom),
        child: Obx(() {
          final addresses = addressCtrl.addresses;
          final selectedId = addressCtrl.selectedAddress.value?.id;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delivery location',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kDarkColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose where to deliver — nearby restaurants update to match.',
                style: GoogleFonts.inter(fontSize: 13, color: kGreyColor),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (addresses.isEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'No saved addresses yet.',
                            style: GoogleFonts.inter(
                                fontSize: 14, color: kGreyColor),
                          ),
                        )
                      else
                        ...addresses.map((a) {
                          final isSelected =
                              a.id != null && a.id == selectedId;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AddressCard(
                              address: a,
                              selected: isSelected,
                              onSelect: () {
                                addressCtrl.selectAddress(a);
                                Navigator.pop(ctx);
                                homeCtrl.refresh();
                              },
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    Get.context!,
                    MaterialPageRoute(
                      builder: (_) => const AddressesScreen(),
                    ),
                  );
                },
                child: Row(
                  children: [
                    const Icon(Icons.add, color: kPrimaryGreen, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Manage addresses',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kPrimaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () => Navigator.push(
        Get.context!,
        MaterialPageRoute(builder: (_) => const SearchScreen()),
      ),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(Icons.search, color: kGreyColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'Find meals that fit your calories',
              style: GoogleFonts.inter(color: kGreyColor, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedSection(HomeController homeCtrl) {
    return Obx(() {
      final meals = homeCtrl.recommended.toList();
      final loading = homeCtrl.isLoadingRecommended.value;
      // Hide the section only once loading is done and there's nothing to show.
      if (meals.isEmpty && !loading) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Recommended for your plan',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kDarkColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 210,
            child: (meals.isEmpty && loading)
                ? const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(kPrimaryGreen),
                      ),
                    ),
                  )
                : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              itemCount: meals.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final meal = meals[i];
                // Order each recommended meal against the branch that actually
                // owns it, not the home feed's restaurant.
                final owner = homeCtrl.recommendedOwner(meal.id);
                return SizedBox(
                  width: 160,
                  child: _MealCard(
                    item: meal,
                    restaurant: owner,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ItemDetailScreen(
                          item: meal,
                          restaurant: owner,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  Widget _buildRestaurantsSection(HomeController homeCtrl) {
    return Obx(() {
      final rests = homeCtrl.restaurants;
      if (rests.isEmpty) {
        // Don't show anything while the first load is still in progress.
        if (homeCtrl.isLoading.value) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kLightGrey),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  size: 48,
                  color: kGreyColor,
                ),
                const SizedBox(height: 12),
                Text(
                  'No restaurants available',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kDarkColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Check back soon — new restaurants are on the way.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: kGreyColor),
                ),
                if (homeCtrl.restaurantsError.value.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    homeCtrl.restaurantsError.value,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: kGreyColor),
                  ),
                ],
              ],
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Explore top rated restaurants',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kDarkColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 188,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              itemCount: rests.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, i) => SizedBox(
                width: 240,
                child: _RestaurantCard(
                  restaurant: rests[i],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          RestaurantMenuScreen(restaurant: rests[i]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _MealCard extends StatelessWidget {
  final MenuItem item;
  final Restaurant restaurant;
  final VoidCallback onTap;

  const _MealCard({
    required this.item,
    required this.restaurant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: SizedBox(
                    height: 110,
                    width: double.infinity,
                    child: Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: kLightGrey,
                        child:
                            const Icon(Icons.restaurant, color: kGreyColor),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kDarkColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (item.nutrition.calories > 0)
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department,
                            size: 13, color: Color(0xFFFF6B35)),
                        const SizedBox(width: 3),
                        Text(
                          '${item.nutrition.calories} kcal',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: kGreyColor),
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),
                  Text(
                    '${item.price.toInt()} EGP',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kPrimaryGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;

  const _RestaurantCard({required this.restaurant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full-bleed banner photo.
                SizedBox(
                  height: 116,
                  width: double.infinity,
                  child: restaurant.bannerUrl.isEmpty
                      ? _bannerFallback()
                      : Image.network(
                          restaurant.bannerUrl,
                          fit: BoxFit.cover,
                          // Some image CDNs (e.g. gstatic thumbnails) reject
                          // requests without a browser User-Agent, which left
                          // the banner blank. Send one so the photo loads.
                          headers: const {
                            'User-Agent':
                                'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
                          },
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                                  ? child
                                  : Container(color: kLightGrey),
                          errorBuilder: (_, _, _) => _bannerFallback(),
                        ),
                ),
                // White bottom bar: name on the left, rating pill on the
                // right. Left padding leaves room for the overlapping logo.
                Padding(
                  padding: const EdgeInsets.fromLTRB(68, 12, 10, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          restaurant.name,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: kDarkColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: kWhite,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: kLightGrey, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                color: Color(0xFFFFB800), size: 13),
                            const SizedBox(width: 2),
                            Text(
                              '${restaurant.rating}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: kDarkColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Logo badge overlapping the banner / white-bar boundary.
            Positioned(
              top: 92,
              left: 12,
              child: Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: kWhite,
                  // Rounded square (not a circle) so non-circular brand logos
                  // show in full instead of getting their corners clipped.
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kLightGrey, width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    restaurant.logoUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.storefront,
                      color: kGreyColor,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Branded banner placeholder shown when a restaurant has no banner photo
  /// (or it fails to load) — a green gradient instead of a flat grey void.
  Widget _bannerFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryGreen, kDarkGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.restaurant_menu, color: kWhite, size: 30),
      ),
    );
  }
}
