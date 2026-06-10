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
            ..._searchCtrl.itemResults.map(
              (e) => _SearchResultTile(
                item: e.item,
                restaurantName: e.restaurant.name,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ItemDetailScreen(
                      item: e.item,
                      restaurant: e.restaurant,
                    ),
                  ),
                ),
              ),
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

class _SearchResultTile extends StatelessWidget {
  final MenuItem item;
  final String restaurantName;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.item,
    required this.restaurantName,
    required this.onTap,
  });

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
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 64,
                child: Image.network(
                  item.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: kLightGrey,
                    child:
                        const Icon(Icons.fastfood, color: kGreyColor, size: 28),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kDarkColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (restaurantName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      restaurantName,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: kPrimaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (item.category.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.category,
                      style:
                          GoogleFonts.inter(fontSize: 12, color: kGreyColor),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${item.nutrition.calories} kcal',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFFF59E0B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${item.nutrition.protein.toInt()}g protein',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF3B82F6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
