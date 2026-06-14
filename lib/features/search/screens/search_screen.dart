import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/features/search/controllers/search_controller.dart' as app;
import 'package:slyce/features/home/models/menu_item.dart';
import 'package:slyce/features/home/models/restaurant.dart';
import 'package:slyce/widgets/loading_widget.dart';
import 'package:slyce/widgets/empty_state_widget.dart';
import 'package:slyce/features/home/screens/item/item_detail_screen.dart';
import 'package:slyce/features/home/screens/restaurant/restaurant_menu_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();
  late final app.SearchController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = Get.find<app.SearchController>();
    // Auto-focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    // Closing the search screen must wipe the search state. The controller is a
    // GetX singleton, so without this the previous query and its results would
    // still be cached and reappear the next time the screen is opened.
    _searchCtrl.clear();
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: kBgColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back, color: kDarkColor),
        ),
        title: _buildSearchField(),
        titleSpacing: 0,
        actions: [
          Obx(() {
            if (_searchCtrl.query.value.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.close, color: kGreyColor, size: 20),
              onPressed: () {
                _textCtrl.clear();
                _searchCtrl.clear();
                _focusNode.requestFocus();
              },
            );
          }),
        ],
      ),
      body: Obx(() {
        if (!_searchCtrl.hasSearched.value) {
          return _buildSuggestions();
        }

        // Delivery search needs a location. Prompt for a delivery address
        // instead of returning unrelated local results.
        if (_searchCtrl.locationMissing.value) {
          return const SlyceEmptyWidget(
            icon: Icons.location_off_rounded,
            title: 'Add a delivery address',
            subtitle:
                'We search meals near your delivery location. Add or select a delivery address to start searching.',
          );
        }

        // The search is API-only; if the request failed, show an error state
        // (no local fallback) so the user can retry.
        if (_searchCtrl.searchError.value) {
          return const SlyceEmptyWidget(
            icon: Icons.cloud_off_rounded,
            title: 'Couldn\'t load results',
            subtitle:
                'Something went wrong while searching. Please check your connection and try again.',
          );
        }

        // Building the per-restaurant item index for the first time.
        if (_searchCtrl.isIndexing.value && !_searchCtrl.hasResults) {
          return const SlyceLoadingWidget(
            message: 'Searching your restaurants...',
          );
        }

        // Nothing matched.
        if (!_searchCtrl.hasResults) {
          return SlyceEmptyWidget(
            icon: Icons.search_off_rounded,
            title: 'No results found',
            subtitle:
                'No restaurants or items match \"${_searchCtrl.query.value}\"',
          );
        }

        return _buildResults();
      }),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _textCtrl,
        focusNode: _focusNode,
        textInputAction: TextInputAction.search,
        style: GoogleFonts.inter(fontSize: 14, color: kDarkColor),
        decoration: InputDecoration(
          hintText: 'Search restaurants or items...',
          hintStyle: GoogleFonts.inter(fontSize: 14, color: kGreyColor),
          prefixIcon:
              const Icon(Icons.search, color: kGreyColor, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: (value) => _searchCtrl.search(value),
        onSubmitted: (value) => _searchCtrl.search(value),
      ),
    );
  }

  /// Empty state shown before the user types. Intentionally shows NO preset
  /// names or keywords — results appear only once the user actually searches.
  Widget _buildSuggestions() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search, size: 48, color: kGreyColor),
            const SizedBox(height: 16),
            Text(
              'Search restaurants near you and the items on their menus.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: kGreyColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    return RefreshIndicator(
      color: kPrimaryGreen,
      onRefresh: () => _searchCtrl.ensureIndex(force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          if (_searchCtrl.restaurantResults.isNotEmpty) ...[
            _sectionHeader('Restaurants', _searchCtrl.restaurantResults.length),
            const SizedBox(height: 12),
            ..._searchCtrl.restaurantResults.map(
              (r) => _RestaurantResultTile(
                restaurant: r,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RestaurantMenuScreen(restaurant: r),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (_searchCtrl.itemResults.isNotEmpty) ...[
            _sectionHeader('Items', _searchCtrl.itemResults.length),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                // Taller than wide to fit image + name + price comfortably.
                childAspectRatio: 0.72,
              ),
              itemCount: _searchCtrl.itemResults.length,
              itemBuilder: (context, i) {
                final e = _searchCtrl.itemResults[i];
                return _SearchResultCard(
                  item: e.item,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ItemDetailScreen(
                        item: e.item,
                        restaurant: e.restaurant,
                        showViewRestaurant: true,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Text(
      '$title ($count)',
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: kDarkColor,
      ),
    );
  }
}

class _RestaurantResultTile extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;

  const _RestaurantResultTile({required this.restaurant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kLightGrey),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  restaurant.logoUrl.isNotEmpty
                      ? restaurant.logoUrl
                      : restaurant.bannerUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(Icons.storefront,
                      color: kGreyColor, size: 28),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kDarkColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (restaurant.location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      restaurant.location,
                      style:
                          GoogleFonts.inter(fontSize: 12, color: kGreyColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (restaurant.rating > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 13, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 4),
                        Text(
                          restaurant.rating.toStringAsFixed(1),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: kGreyColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: kGreyColor),
          ],
        ),
      ),
    );
  }
}

/// Grid card for an item search result: image on top, then name and price,
/// plus a "+" button. Mirrors the product-card layout used elsewhere in the
/// app. Adding requires choosing a size, so "+" opens the detail screen.
class _SearchResultCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onTap;

  const _SearchResultCard({
    required this.item,
    required this.onTap,
  });

  String get _priceLabel {
    final p = item.price;
    // Base price; the exact size price is chosen on the detail screen.
    if (p <= 0) return '';
    return 'EGP ${p.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with the "+" action overlaid in the corner.
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: kLightGrey,
                        child: const Icon(
                          Icons.fastfood,
                          color: kGreyColor,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onTap,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: kWhite,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: kDarkColor.withValues(alpha: 0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add,
                          color: kPrimaryGreen,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kDarkColor,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_priceLabel.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _priceLabel,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kDarkColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
