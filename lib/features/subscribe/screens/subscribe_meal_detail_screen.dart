import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/features/home/models/menu_item.dart';
import 'package:slyce/features/home/models/meal_model.dart';
import 'package:slyce/features/home/repositories/menu_repository.dart';
import 'package:slyce/features/subscribe/controllers/subscribe_controller.dart';
import 'package:slyce/widgets/app_snackbar.dart';

/// "View" a meal from inside the subscription flow.
///
/// Loads the meal's full details (ingredients, calories, macros and real
/// sizes) from the SAME meals endpoint used everywhere else (GET /meals/:id),
/// then lets the customer pick a size and "Add to subscription". Unlike the
/// cart's item detail screen, this adds the chosen size to the subscription
/// selection instead of the cart.
class SubscribeMealDetailScreen extends StatefulWidget {
  final MenuItem item;
  const SubscribeMealDetailScreen({super.key, required this.item});

  @override
  State<SubscribeMealDetailScreen> createState() =>
      _SubscribeMealDetailScreenState();
}

class _SubscribeMealDetailScreenState
    extends State<SubscribeMealDetailScreen> {
  final _menuRepo = MenuRepository();
  final SubscribeController _subCtrl = Get.find<SubscribeController>();

  // The full meal (ingredients + nutrition) loaded from GET /meals/:id.
  MenuItem _detail = const MenuItem(
    id: '',
    name: '',
    description: '',
    price: 0,
    imageUrl: '',
    category: '',
    nutrition: NutritionInfo(calories: 0, protein: 0, fats: 0, carbs: 0),
  );

  // Selectable sizes carry the real MealSizeId GUID required by the API.
  List<MenuPortion> _portions = [];
  List<MealSizeModel> _sizes = [];
  MenuPortion? _selectedPortion;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _detail = widget.item;
    _portions = List<MenuPortion>.from(widget.item.portions);
    // Don't pre-select any size on open — a chip only turns green once the user
    // taps it. We still restore a previously chosen size in _loadDetail if this
    // meal is already part of the subscription.
    _selectedPortion = null;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final meal = await _menuRepo.getMealById(widget.item.id);
      final detail = meal.toMenuItem();
      if (!mounted) return;
      setState(() {
        _detail = MenuItem(
          id: widget.item.id,
          name: detail.name.isNotEmpty ? detail.name : widget.item.name,
          description: detail.description.isNotEmpty
              ? detail.description
              : widget.item.description,
          price: detail.price > 0 ? detail.price : widget.item.price,
          imageUrl: detail.imageUrl.isNotEmpty
              ? detail.imageUrl
              : widget.item.imageUrl,
          category: detail.category,
          nutrition: detail.nutrition.calories > 0
              ? detail.nutrition
              : widget.item.nutrition,
          extras: detail.extras,
          ingredients: detail.ingredients.isNotEmpty
              ? detail.ingredients
              : widget.item.ingredients,
          portions: detail.portions,
        );
        _sizes = meal.sizes
            .where((s) => s.id != null && s.id!.isNotEmpty)
            .toList();
        if (detail.portions.isNotEmpty) {
          _portions = detail.portions;
          // Only restore a selection if this meal is ALREADY in the
          // subscription. Otherwise leave nothing selected so no chip is green
          // when the screen first opens.
          final existing = _subCtrl.selectionForMeal(widget.item.id);
          final existingId = existing?['MealSizeId']?.toString();
          if (existingId != null && existingId.isNotEmpty) {
            _selectedPortion = _portions.firstWhere(
              (p) => p.id == existingId,
              orElse: () => _portions.first,
            );
          } else {
            _selectedPortion = null;
          }
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  double _priceForPortion(MenuPortion? portion) {
    if (portion != null && _sizes.isNotEmpty) {
      for (final s in _sizes) {
        if (s.id == portion.id) return s.price;
      }
    }
    return _detail.price;
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
  /// back to the loaded meal's figures when sizes carry none.
  NutritionInfo get _activeNutrition {
    final s = _activeSize;
    if (s != null &&
        (s.nutrition.calories > 0 ||
            s.nutrition.protein > 0 ||
            s.nutrition.fats > 0 ||
            s.nutrition.carbs > 0)) {
      return s.nutrition;
    }
    return _detail.nutrition;
  }

  /// Ingredient labels for the active size, falling back to the loaded meal's
  /// ingredients and finally the description.
  List<String> get _activeIngredientNames {
    final s = _activeSize;
    if (s != null && s.ingredients.isNotEmpty) {
      return s.ingredients.map((ing) {
        final amt = ing.quantity ?? '';
        return amt.isNotEmpty ? '${ing.name} ($amt)' : ing.name;
      }).toList();
    }
    if (_detail.ingredients.isNotEmpty) {
      return _detail.ingredients
          .map((ing) =>
              ing.amount.isNotEmpty ? '${ing.name} (${ing.amount})' : ing.name)
          .toList();
    }
    return _ingredientsFromDescription(_detail.description);
  }

  bool get _isAdded => _subCtrl.selectionForMeal(widget.item.id) != null;

  @override
  Widget build(BuildContext context) {
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
                  Text(
                    _detail.name,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: kDarkColor,
                    ),
                  ),
                  if (_detail.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _detail.description,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: kGreyColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _buildPortionPicker(),
                  const SizedBox(height: 20),
                  _buildNutrition(),
                  const SizedBox(height: 20),
                  _buildIngredients(),
                  const SizedBox(height: 110),
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
          decoration:
              const BoxDecoration(color: kWhite, shape: BoxShape.circle),
          child: const Icon(Icons.arrow_back, color: kDarkColor, size: 20),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Image.network(
          _detail.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(color: kLightGrey),
        ),
      ),
    );
  }

  Widget _buildPortionPicker() {
    if (_loading) {
      return Row(
        children: [
          Text(
            'Pick your size',
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
          'Pick your size',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: kDarkColor,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _portions.map((p) {
            final selected = p == _selectedPortion;
            return GestureDetector(
              onTap: () => setState(() => _selectedPortion = p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNutrition() {
    final n = _activeNutrition;
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
              _CalorieRing(calories: n.calories),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _NutrientBar(
                        label: 'Protein',
                        value: n.protein,
                        max: 60,
                        color: const Color(0xFF4CAF50)),
                    const SizedBox(height: 8),
                    _NutrientBar(
                        label: 'Fats',
                        value: n.fats,
                        max: 50,
                        color: const Color(0xFFFF9800)),
                    const SizedBox(height: 8),
                    _NutrientBar(
                        label: 'Carbs',
                        value: n.carbs,
                        max: 100,
                        color: const Color(0xFFE53935)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIngredients() {
    // Prefer the meal's real ingredient list; if the backend doesn't provide
    // one, fall back to the description, which is usually a comma-separated
    // ingredient list (e.g. "Slices of chicken, onion, capsicum, mayo").
    final names = _activeIngredientNames;

    if (names.isEmpty) {
      if (_loading) return const SizedBox.shrink();
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
          const SizedBox(height: 8),
          Text(
            'No ingredients listed for this meal.',
            style: GoogleFonts.inter(fontSize: 12, color: kGreyColor),
          ),
        ],
      );
    }
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kCardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style:
                        GoogleFonts.inter(fontSize: 12, color: kDarkColor),
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
          BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, -4)),
        ],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            // Until the customer picks a size we don't show a price — a bare
            // default price next to no selected chip was confusing.
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
                      'Price',
                      style:
                          GoogleFonts.inter(fontSize: 11, color: kGreyColor),
                    ),
                    Text(
                      '${_priceForPortion(_selectedPortion).toInt()} EGP',
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
            child: Obx(() {
              final added = _subCtrl.selectionForMeal(widget.item.id) != null;
              return GestureDetector(
                onTap: () => _onAddOrRemove(context, added),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: added ? kCardColor : kPrimaryGreen,
                    borderRadius: BorderRadius.circular(16),
                    border: added
                        ? Border.all(color: kPrimaryGreen, width: 1.5)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    added ? 'Remove from subscription' : 'Add to subscription',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: added ? kPrimaryGreen : kWhite,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _onAddOrRemove(BuildContext context, bool added) {
    if (added) {
      _subCtrl.removeMealById(widget.item.id);
      _snack(context, 'Removed from subscription');
      return;
    }
    final portion = _selectedPortion;
    if (portion == null) {
      _snack(
        context,
        _loading
            ? 'Loading sizes, please wait\u2026'
            : _portions.isEmpty
                ? 'This meal has no available size to subscribe.'
                : 'Please pick a size first.',
        error: true,
      );
      return;
    }
    _subCtrl.addMealSize(
      portion.id,
      1,
      mealId: widget.item.id,
      mealName: _detail.name,
      sizeName: portion.name,
      price: _priceForPortion(portion),
      imageUrl: _detail.imageUrl,
    );
    _snack(context, 'Added to subscription');
    Navigator.pop(context);
  }

  void _snack(BuildContext context, String message, {bool error = false}) {
    showAppSnackbar(
      message,
      type: error ? AppSnackbarType.error : AppSnackbarType.success,
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
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFE53935)),
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
              value: max <= 0 ? 0 : (value / max).clamp(0.0, 1.0),
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
