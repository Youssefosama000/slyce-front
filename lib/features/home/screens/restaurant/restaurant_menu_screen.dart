import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/core/network/api_exceptions.dart';
import 'package:slyce/features/home/models/restaurant.dart';
import 'package:slyce/features/home/models/menu_item.dart';
import 'package:slyce/features/home/repositories/menu_repository.dart';
import 'package:slyce/features/home/screens/item/item_detail_screen.dart';
import 'package:slyce/features/subscribe/screens/subscribe_screen.dart';
import 'restaurant_info_screen.dart';

class RestaurantMenuScreen extends StatefulWidget {
  final Restaurant restaurant;
  const RestaurantMenuScreen({super.key, required this.restaurant});

  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen> {
  final MenuRepository _repo = MenuRepository();

  String _selectedCategory = 'All';
  bool _loadingMenu = true;
  String _menuError = '';
  List<MenuItem> _menuItems = const [];
  List<String> _categories = const ['All'];
  bool? _isOpen; // null => undetermined, badge hidden

  @override
  void initState() {
    super.initState();
    _loadMenu();
    _loadOpenStatus();
  }

  /// Resolve the branch working hours (the `nearby` feed carries none) and
  /// compute today's open/closed status. No hard-coded badge.
  Future<void> _loadOpenStatus() async {
    final branchId = widget.restaurant.primaryBranchId;
    if (branchId == null || branchId.isEmpty) return;
    try {
      final branch = await _repo.getBranchDetails(branchId);
      if (!mounted) return;
      setState(() => _isOpen = _isOpenNow(branch.openingHours));
    } catch (_) {
      // Leave _isOpen null so the badge stays hidden.
    }
  }

  bool? _isOpenNow(List<OpeningHours> hours) {
    if (hours.isEmpty) return null;
    final now = DateTime.now();
    // DateTime.weekday is Mon=1..Sun=7; map to Sun=0..Sat=6 to match day names.
    final todayIndex = now.weekday % 7;
    OpeningHours? today;
    for (final h in hours) {
      if (_dayIndex(h.day) == todayIndex) {
        today = h;
        break;
      }
    }
    if (today == null) return false;
    final open = _toMinutes(today.open);
    var close = _toMinutes(today.close);
    if (open == null || close == null) return null;
    final nowMinutes = now.hour * 60 + now.minute;
    if (close <= open) {
      // Hours cross midnight (e.g. 18:00 \u2013 02:00) or close at midnight (00:00).
      close += 24 * 60;
      final adjustedNow =
          nowMinutes < open ? nowMinutes + 24 * 60 : nowMinutes;
      return adjustedNow >= open && adjustedNow <= close;
    }
    return nowMinutes >= open && nowMinutes <= close;
  }

  /// Normalize a day label to an index where Sunday=0 \u2026 Saturday=6, tolerating
  /// case, surrounding spaces, abbreviations ("Sat"), and numeric days
  /// (0\u20136 Sunday-based, or 7 for Sunday). Returns null when unrecognised, so a
  /// mismatched format never silently marks an open restaurant as closed.
  int? _dayIndex(String raw) {
    final r = raw.trim().toLowerCase();
    if (r.isEmpty) return null;
    final n = int.tryParse(r);
    if (n != null) {
      if (n >= 0 && n <= 6) return n;
      if (n == 7) return 0;
      return null;
    }
    const names = [
      'sunday',
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
    ];
    for (var i = 0; i < names.length; i++) {
      if (names[i].startsWith(r) || r.startsWith(names[i].substring(0, 3))) {
        return i;
      }
    }
    return null;
  }

  int? _toMinutes(String time) {
    if (time.isEmpty) return null;
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// Loads the restaurant's menu from the API.
  ///
  /// The menu is per-RESTAURANT (one menu per restaurant), fetched with the
  /// restaurantId — `widget.restaurant.id` resolves to the restaurantId from
  /// the `nearby` endpoint. (Ordering, separately, uses the branchId.) No
  /// hard-coded fallback.
  Future<void> _loadMenu() async {
    // Already arrived fully loaded (e.g. opened from a populated feed).
    if (widget.restaurant.menu.isNotEmpty) {
      _applyMenu(widget.restaurant.menu, widget.restaurant.categories);
      setState(() => _loadingMenu = false);
      return;
    }

    final rid = widget.restaurant.id;
    if (rid.isEmpty) {
      setState(() {
        _loadingMenu = false;
        _menuError = "This restaurant's menu isn't available yet.";
      });
      return;
    }

    try {
      final response = await _repo.getMenu(rid);
      final items = response.allMeals.map((m) => m.toMenuItem()).toList();
      // The menu endpoint can lag behind deletions and still list removed
      // meals (GET /v1/meals/:id returns 404 for them). Drop those so deleted
      // meals never show on the restaurant page. Categories are built from the
      // surviving items so empty categories disappear too.
      final live = await _filterToLiveMeals(items);
      if (!mounted) return;
      final cats = <String>[];
      for (final item in live) {
        if (item.category.isNotEmpty && !cats.contains(item.category)) {
          cats.add(item.category);
        }
      }
      _applyMenu(live, cats);
      setState(() => _loadingMenu = false);
    } on ApiException catch (_) {
      setState(() {
        _loadingMenu = false;
        _menuError = "We couldn't load the menu right now. Please try again.";
      });
    } catch (_) {
      setState(() {
        _loadingMenu = false;
        _menuError = "We couldn't load the menu right now. Please try again.";
      });
    }
  }

  void _applyMenu(List<MenuItem> items, List<String> categories) {
    _menuItems = items;
    _categories = ['All', ...categories.where((c) => c.isNotEmpty)];
    _selectedCategory = 'All';
  }

  /// Keep only the meals that still exist in the live catalogue.
  ///
  /// Each meal is verified with GET /v1/meals/:id. A 404 means the meal was
  /// removed, so it is dropped. On any other error (network/timeout/5xx) the
  /// meal is kept, so a transient failure never wrongly empties the menu.
  /// Checks run in parallel to keep loading fast.
  Future<List<MenuItem>> _filterToLiveMeals(List<MenuItem> items) async {
    if (items.isEmpty) return items;
    final checks = await Future.wait(
      items.map((item) async {
        if (item.id.isEmpty) return null;
        try {
          await _repo.getMealById(item.id);
          return item;
        } on ApiException catch (e) {
          return e.statusCode == 404 ? null : item;
        } catch (_) {
          return item;
        }
      }),
    );
    return checks.whereType<MenuItem>().toList();
  }

  List<MenuItem> get _visibleItems => _selectedCategory == 'All'
      ? _menuItems
      : _menuItems.where((i) => i.category == _selectedCategory).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(child: _buildRestaurantInfo()),
          if (_loadingMenu)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_menuError.isNotEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    _menuError,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: kGreyColor),
                  ),
                ),
              ),
            )
          else ...[
            SliverToBoxAdapter(child: _buildCategoryTabs()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final items = _visibleItems;
                    if (items.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            'No items in this category',
                            style: GoogleFonts.inter(color: kGreyColor),
                          ),
                        ),
                      );
                    }
                    return _MenuItemTile(
                      item: items[i],
                      restaurant: widget.restaurant,
                    );
                  },
                  childCount: _visibleItems.isEmpty ? 1 : _visibleItems.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: kBgColor,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: kWhite, shape: BoxShape.circle),
          child: const Icon(Icons.arrow_back, color: kDarkColor, size: 20),
        ),
      ),
      actions: [
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RestaurantInfoScreen(restaurant: widget.restaurant),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Info',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kDarkColor,
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              widget.restaurant.bannerUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(color: kDarkGreen),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.4),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kLightGrey),
            ),
            child: Image.network(
              widget.restaurant.logoUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.restaurant,
                color: kPrimaryGreen,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.restaurant.name,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: kDarkColor,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFFFB800), size: 14),
                    const SizedBox(width: 3),
                    Text(
                      '${widget.restaurant.rating}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kDarkColor,
                      ),
                    ),
                    if (_isOpen != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (_isOpen! ? kPrimaryGreen : kGreyColor)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _isOpen! ? 'Open' : 'Closed',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _isOpen! ? kPrimaryGreen : kGreyColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildSubscribeButton(),
        ],
      ),
    );
  }

  /// Opens the subscription flow for THIS restaurant. The subscribe page then
  /// loads this restaurant's meals (same meals endpoints) so the customer can
  /// view ingredients/calories and add meals to their subscription.
  Widget _buildSubscribeButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SubscribeScreen(restaurant: widget.restaurant),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: kPrimaryGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.restaurant_menu, color: kWhite, size: 16),
            const SizedBox(width: 6),
            Text(
              'Subscribe',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final cat = _categories[i];
            final selected = cat == _selectedCategory;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: selected ? kPrimaryGreen : kCardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  cat,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: selected ? kWhite : kDarkColor,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  final MenuItem item;
  final Restaurant restaurant;

  const _MenuItemTile({required this.item, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ItemDetailScreen(item: item, restaurant: restaurant),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 80,
                height: 80,
                child: Image.network(
                  item.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: kLightGrey,
                    child: const Icon(Icons.fastfood, color: kGreyColor),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: GoogleFonts.inter(fontSize: 11, color: kGreyColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${item.nutrition.calories} kcal',
                        style: GoogleFonts.inter(fontSize: 11, color: kGreyColor),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: kPrimaryGreen,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${item.price.toInt()} EGP',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: kWhite,
                          ),
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


