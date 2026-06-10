import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/features/cart/controllers/cart_controller.dart';
import 'package:slyce/features/home/models/meal_model.dart';
import 'package:slyce/features/home/models/menu_item.dart';
import 'package:slyce/features/home/models/restaurant.dart';
import 'package:slyce/features/home/repositories/menu_repository.dart';
import 'package:slyce/widgets/app_snackbar.dart';

class ItemDetailScreen extends StatefulWidget {
  final MenuItem item;
  final Restaurant restaurant;
  const ItemDetailScreen({super.key, required this.item, required this.restaurant});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  final _menuRepo = MenuRepository();

  // Selectable sizes carry the real MealSizeId GUID required by the cart API.
  List<MenuPortion> _portions = [];
  // Sizes carry the per-portion price (the menu item only has a base price).
  List<MealSizeModel> _sizes = [];
  MenuPortion? _selectedPortion;
  bool _loadingSizes = true;

  final Set<String> _selectedExtras = {};
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _portions = List<MenuPortion>.from(widget.item.portions);
    // Don't pre-select any portion on open — a chip only turns green once the
    // user taps it.
    _selectedPortion = null;
    _loadSizes();
  }

  /// Load the meal's real sizes from GET /meals/:id. The menu list does not
  /// include sizes, so the passed-in item often has none. Each size carries
  /// its MealSizeId, which the cart endpoint requires as `sizeId`.
  Future<void> _loadSizes() async {
    try {
      final meal = await _menuRepo.getMealById(widget.item.id);
      final portions = meal.toMenuItem().portions;
      final sizes =
          meal.sizes.where((s) => (s.id ?? '').isNotEmpty).toList();
      if (!mounted) return;
      setState(() {
        if (portions.isNotEmpty) {
          _portions = portions;
          // Leave nothing selected so no chip is green when the screen opens.
        }
        if (sizes.isNotEmpty) _sizes = sizes;
        _loadingSizes = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSizes = false);
    }
  }

  double get _total {
    final extrasTotal = widget.item.extras
        .where((e) => _selectedExtras.contains(e.id))
        .fold(0.0, (s, e) => s + e.price);
    return (_priceForPortion(_selectedPortion) + extrasTotal) * _quantity;
  }

  /// Price for the selected portion. Each size carries its own price; fall
  /// back to the item's base price when no size is selected or matched.
  double _priceForPortion(MenuPortion? portion) {
    if (portion != null) {
      for (final s in _sizes) {
        if (s.id == portion.id) return s.price;
      }
    }
    return widget.item.price;
  }

  /// The size whose macros/ingredients should be displayed: the selected one,
  /// otherwise the first (cheapest) size as a sensible default.
  MealSizeModel? get _activeSize {
    final sel = _selectedPortion;
    if (sel != null) {
      for (final s in _sizes) {
        if (s.id == sel.id) return s;
      }
    }
    return _sizes.isNotEmpty ? _sizes.first : null;
  }

  /// Nutrition for the active size (each size has its own macros), falling
  /// back to the menu item's figures when sizes carry none.
  NutritionInfo get _activeNutrition {
    final s = _activeSize;
    if (s != null &&
        (s.nutrition.calories > 0 ||
            s.nutrition.protein > 0 ||
            s.nutrition.fats > 0 ||
            s.nutrition.carbs > 0)) {
      return s.nutrition;
    }
    return widget.item.nutrition;
  }

  /// Ingredient labels for the active size, falling back to the menu item's
  /// ingredients and finally the description.
  List<String> get _activeIngredientNames {
    final s = _activeSize;
    if (s != null && s.ingredients.isNotEmpty) {
      return s.ingredients.map((ing) {
        final amt = ing.quantity ?? '';
        return amt.isNotEmpty ? '${ing.name} ($amt)' : ing.name;
      }).toList();
    }
    if (widget.item.ingredients.isNotEmpty) {
      return widget.item.ingredients
          .map((ing) =>
              ing.amount.isNotEmpty ? '${ing.name} (${ing.amount})' : ing.name)
          .toList();
    }
    return _ingredientsFromDescription(widget.item.description);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      backgroundColor: kBgColor,
      body: CustomScrollView(
        slivers: [
          _buildImageAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleRow(item),
                  const SizedBox(height: 16),
                  _buildPortionPicker(),
                  if (item.extras.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildExtras(item),
                  ],
                  const SizedBox(height: 20),
                  _buildNutrition(item),
                  const SizedBox(height: 20),
                  _buildIngredients(item),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomBar(context),
    );
  }

  Widget _buildImageAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 260,
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
      flexibleSpace: FlexibleSpaceBar(
        background: Image.network(
          widget.item.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(color: kLightGrey),
        ),
      ),
    );
  }

  Widget _buildTitleRow(MenuItem item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            item.name,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: kDarkColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() {
                if (_quantity > 1) _quantity--;
              }),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: kCardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.remove, size: 16, color: kDarkColor),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '$_quantity',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kDarkColor,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _quantity++),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: kPrimaryGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, size: 16, color: kWhite),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPortionPicker() {
    if (_loadingSizes) {
      return Row(
        children: [
          Text(
            'Pick your portion',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: kDarkColor,
            ),
          ),
          const SizedBox(width: 12),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: kPrimaryGreen),
          ),
        ],
      );
    }
    if (_portions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pick your portion',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: kDarkColor,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: _portions.map((p) {
            final selected = p == _selectedPortion;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => setState(() => _selectedPortion = p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? kPrimaryGreen : kCardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    p.name,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: selected ? kWhite : kDarkColor,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildExtras(MenuItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add Extras',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: kDarkColor,
          ),
        ),
        const SizedBox(height: 10),
        ...item.extras.map((extra) {
          final selected = _selectedExtras.contains(extra.id);
          return GestureDetector(
            onTap: () => setState(() {
              if (selected) {
                _selectedExtras.remove(extra.id);
              } else {
                _selectedExtras.add(extra.id);
              }
            }),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: kCardColor,
                borderRadius: BorderRadius.circular(12),
                border: selected
                    ? Border.all(color: kPrimaryGreen, width: 1.5)
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      extra.name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: kDarkColor,
                      ),
                    ),
                  ),
                  Text(
                    '+${extra.price.toInt()} EGP',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kGreyColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: selected ? kPrimaryGreen : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? kPrimaryGreen : kLightGrey,
                        width: 1.5,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 13, color: kWhite)
                        : null,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNutrition(MenuItem item) {
    final n = _activeNutrition;
    // Scale the nutrition figures by the selected quantity so the calorie
    // counter (and macros) increase as the user adds more of the meal.
    final q = _quantity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nutrition Info',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: kDarkColor,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _CalorieRing(calories: n.calories * q),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _NutrientBar(label: 'Protein', value: n.protein * q, max: 60.0 * q, color: const Color(0xFF4CAF50)),
                    const SizedBox(height: 8),
                    _NutrientBar(label: 'Fats', value: n.fats * q, max: 50.0 * q, color: const Color(0xFFFF9800)),
                    const SizedBox(height: 8),
                    _NutrientBar(label: 'Carbs', value: n.carbs * q, max: 100.0 * q, color: const Color(0xFFE53935)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIngredients(MenuItem item) {
    // Prefer real ingredients; otherwise fall back to the description, which
    // is usually a comma-separated ingredient list.
    final names = _activeIngredientNames;
    if (names.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ingredients',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: kDarkColor,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: names
              .map(
                (label) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kCardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: GoogleFonts.inter(fontSize: 12, color: kDarkColor),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  /// Split a free-text description into ingredient chips. Many meals store
  /// their ingredient list in the description as a comma-separated string.
  List<String> _ingredientsFromDescription(String description) {
    final desc = description.trim();
    if (desc.isEmpty) return const [];
    return desc
        .split(RegExp(r'[,\u060C]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      decoration: const BoxDecoration(
        color: kBgColor,
        boxShadow: [
          BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            // Until the customer picks a size we don't show a price — a bare
            // default amount next to no selected chip was confusing.
            children: _selectedPortion == null
                ? [
                    Text(
                      'Select a size',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kGreyColor,
                      ),
                    ),
                  ]
                : [
                    Text(
                      'Total amount',
                      style:
                          GoogleFonts.inter(fontSize: 11, color: kGreyColor),
                    ),
                    Text(
                      '${_total.toInt()} EGP',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: kDarkColor,
                      ),
                    ),
                  ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final cartCtrl = Get.find<CartController>();

                final portion = _selectedPortion;
                if (portion == null) {
                  showAppSnackbar(
                    _loadingSizes
                        ? 'Loading sizes, please wait…'
                        : _portions.isEmpty
                            ? 'This item has no available size to order.'
                            : 'Please pick a size first.',
                    type: AppSnackbarType.error,
                  );
                  return;
                }

                final success = await cartCtrl.addToCart(
                  mealId: widget.item.id,
                  sizeId: portion.id,
                  branchId: widget.restaurant.defaultBranchId ?? '',
                  quantity: _quantity,
                  restaurant: widget.restaurant,
                );

                if (!context.mounted) return;
                showAppSnackbar(
                  success
                      ? 'Added to cart!'
                      : (cartCtrl.errorMessage.value.isNotEmpty
                          ? cartCtrl.errorMessage.value
                          : 'Failed to add to cart'),
                  type: success
                      ? AppSnackbarType.success
                      : AppSnackbarType.error,
                );
                if (success) Navigator.pop(context);
              },
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: kPrimaryGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Add To Cart',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kWhite,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalorieRing extends StatelessWidget {
  final int calories;
  const _CalorieRing({required this.calories});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: (calories / 800).clamp(0.0, 1.0),
              strokeWidth: 8,
              backgroundColor: kLightGrey,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE53935)),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$calories',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: kDarkColor,
                ),
              ),
              Text(
                'kcal',
                style: GoogleFonts.inter(fontSize: 11, color: kGreyColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NutrientBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color color;

  const _NutrientBar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 46,
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: kGreyColor),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (value / max).clamp(0.0, 1.0),
              backgroundColor: kLightGrey,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${value.toInt()}g',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: kDarkColor,
          ),
        ),
      ],
    );
  }
}


