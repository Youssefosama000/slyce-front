import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/features/home/models/restaurant.dart';
import 'package:slyce/features/home/models/menu_item.dart';
import 'package:slyce/features/subscribe/controllers/subscribe_controller.dart';
import 'package:slyce/features/subscribe/screens/subscribe_meal_detail_screen.dart';
import 'package:slyce/features/profile/controllers/address_controller.dart';
import 'package:slyce/features/profile/models/address_model.dart';
import 'package:slyce/widgets/address_card.dart';
import 'package:slyce/widgets/app_snackbar.dart';

class SubscribeScreen extends StatefulWidget {
  /// The restaurant this subscription is for when opened from a restaurant's
  /// "Subscribe" button. When opened from the bottom "Subscribe" tab to COMPLETE
  /// an in-progress subscription, this is null and the screen reuses whatever
  /// restaurant/meals are already held by [SubscribeController].
  final Restaurant? restaurant;
  const SubscribeScreen({super.key, this.restaurant});

  @override
  State<SubscribeScreen> createState() => _SubscribeScreenState();
}

class _SubscribeScreenState extends State<SubscribeScreen> {
  /// Currently selected meal-category filter ("All" shows everything).
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    // Defer to after the first frame so loading the restaurant's branches and
    // meals (which mutates observables) never fires during build.
    // Only (re)initialise for a specific restaurant when opened from that
    // restaurant's page. On the bottom "Subscribe" tab (no restaurant) we keep
    // whatever meals/restaurant the customer already picked so they can finish.
    final restaurant = widget.restaurant;
    if (restaurant == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Get.find<SubscribeController>().initForRestaurant(restaurant);
    });
  }

  @override
  Widget build(BuildContext context) {
    final subCtrl = Get.find<SubscribeController>();

    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: kBgColor,
        elevation: 0,
        title: Text(
          'Subscribe',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: kDarkColor,
          ),
        ),
      ),
      body: widget.restaurant == null
          ? Obx(() {
              final inProgress =
                  subCtrl.selectedRestaurantId.value != null ||
                      subCtrl.selectedMealSizes.isNotEmpty;
              return inProgress
                  ? _buildForm(context, subCtrl)
                  : _buildEmptyState();
            })
          : _buildForm(context, subCtrl),
      bottomSheet: Obx(() {
        // Read the observables up-front so this Obx ALWAYS registers a reactive
        // dependency. Previously the condition started with `widget.restaurant
        // == null`, which short-circuits when the screen is opened from a
        // restaurant page (widget.restaurant != null) — leaving the Obx without
        // any observable and triggering GetX's "improper use of GetX" error
        // that painted the whole screen red.
        final hasSelectedRestaurant =
            subCtrl.selectedRestaurantId.value != null;
        final hasSelectedMeals = subCtrl.selectedMealSizes.isNotEmpty;
        final noSubscription = widget.restaurant == null &&
            !hasSelectedRestaurant &&
            !hasSelectedMeals;
        return noSubscription
            ? const SizedBox.shrink()
            : _buildSubscribeButton(subCtrl);
      }),
    );
  }

  /// The full subscription form: restaurant header, meal picker, billing cycle,
  /// delivery days/schedule, and delivery details.
  Widget _buildForm(BuildContext context, SubscribeController subCtrl) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      children: [
        _buildRestaurantHeader(),
        const SizedBox(height: 20),
        _buildMealsSection(subCtrl),
        const SizedBox(height: 20),
        _buildBillingCycle(subCtrl),
        const SizedBox(height: 20),
        _buildDeliveryDays(subCtrl),
        const SizedBox(height: 20),
        _buildScheduleFields(context, subCtrl),
        const SizedBox(height: 20),
        _buildDeliveryDetails(context),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Shown on the bottom "Subscribe" tab when there is no subscription in
  /// progress yet (the customer hasn't picked meals from any restaurant).
  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.restaurant_menu, size: 64, color: kGreyColor),
        const SizedBox(height: 16),
        Text(
          'No subscription in progress',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kDarkColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Open any restaurant, tap Subscribe and pick your meals, then come back here to complete your subscription.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 13, color: kGreyColor),
        ),
      ],
    );
  }

  /// The meal picker: lists EVERY meal the selected restaurant offers (not a
  /// fixed subset). Tap a meal (or its Add button) to choose a size and add it
  /// to the subscription.
  Widget _buildMealsSection(SubscribeController subCtrl) {
    return Obx(() {
      final items = subCtrl.meals.toList();

      // Build the category list from the available meals.
      final cats = <String>[];
      for (final item in items) {
        if (item.category.isNotEmpty && !cats.contains(item.category)) {
          cats.add(item.category);
        }
      }
      final categories = ['All', ...cats];
      // Keep the selection valid if the meals (and their categories) change.
      if (_selectedCategory != 'All' &&
          !categories.contains(_selectedCategory)) {
        _selectedCategory = 'All';
      }
      final visible = _selectedCategory == 'All'
          ? items
          : items.where((i) => i.category == _selectedCategory).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose your meals',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: kDarkColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a meal to pick a size and add it.',
            style: GoogleFonts.inter(fontSize: 12, color: kGreyColor),
          ),
          const SizedBox(height: 12),
          // Category filter chips (hidden when there's only one category).
          if (categories.length > 1) ...[
            _buildCategoryChips(categories),
            const SizedBox(height: 14),
          ],
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  subCtrl.isLoadingMeals.value
                      ? 'Loading meals...'
                      : 'No meals available right now.',
                  style: const TextStyle(color: kGreyColor),
                ),
              ),
            )
          else if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No meals in this category',
                  style: GoogleFonts.inter(color: kGreyColor),
                ),
              ),
            )
          else
            ...visible.map(
              (item) => _SubscribeItemTile(
                key: ValueKey(item.id),
                item: item,
              ),
            ),
        ],
      );
    });
  }

  /// Horizontal, scrollable category filter chips for the meal picker.
  Widget _buildCategoryChips(List<String> categories) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = categories[i];
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
    );
  }

  /// Shows which restaurant this subscription is for. There's no picker — the
  /// subscription is always tied to the restaurant the customer opened it from.
  /// The restaurant the subscription is for: the one passed in, or (when opened
  /// from the bottom "Subscribe" tab to complete an in-progress subscription)
  /// whichever restaurant the controller already holds.
  Restaurant? _activeRestaurant() {
    if (widget.restaurant != null) return widget.restaurant;
    final subCtrl = Get.find<SubscribeController>();
    final id = subCtrl.selectedRestaurantId.value;
    for (final restaurant in subCtrl.restaurants) {
      if (restaurant.id == id) return restaurant;
    }
    return subCtrl.restaurants.isNotEmpty ? subCtrl.restaurants.first : null;
  }

  Widget _buildRestaurantHeader() {
    final r = _activeRestaurant();
    if (r == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(16),
      ),
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: r.logoUrl.isNotEmpty
                  ? Image.network(
                      r.logoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => _logoFallback(),
                    )
                  : _logoFallback(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subscribing to',
                  style: GoogleFonts.inter(fontSize: 11, color: kGreyColor),
                ),
                const SizedBox(height: 2),
                Text(
                  r.name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kDarkColor,
                  ),
                ),
                if (r.location.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    r.location,
                    style: GoogleFonts.inter(fontSize: 12, color: kGreyColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoFallback() => const Center(
        child: Icon(Icons.storefront, color: kGreyColor),
      );

  Widget _buildBillingCycle(SubscribeController subCtrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Billing Cycle',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: kDarkColor,
          ),
        ),
        const SizedBox(height: 10),
        Obx(() => Container(
              height: 42,
              decoration: BoxDecoration(
                color: kCardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _CycleTab(
                    label: 'Weekly',
                    selected: subCtrl.isWeekly.value,
                    onTap: () => subCtrl.isWeekly.value = true,
                  ),
                  _CycleTab(
                    label: 'Monthly',
                    selected: !subCtrl.isWeekly.value,
                    onTap: () => subCtrl.isWeekly.value = false,
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildDeliveryDays(SubscribeController subCtrl) {
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final dayMapping = {
      'Sun': 'Sunday',
      'Mon': 'Monday',
      'Tue': 'Tuesday',
      'Wed': 'Wednesday',
      'Thu': 'Thursday',
      'Fri': 'Friday',
      'Sat': 'Saturday',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select delivery days',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: kDarkColor,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: days.map((day) {
            return Obx(() {
              final fullDay = dayMapping[day]!;
              final selected = subCtrl.selectedDays.contains(fullDay);
              return GestureDetector(
                onTap: () => subCtrl.toggleDay(fullDay),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: selected ? kPrimaryGreen : kCardColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    day.substring(0, 1),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? kWhite : kGreyColor,
                    ),
                  ),
                ),
              );
            });
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: days.map((day) {
            return SizedBox(
              width: 38,
              child: Center(
                child: Text(
                  day,
                  style: GoogleFonts.inter(fontSize: 10, color: kGreyColor),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildScheduleFields(BuildContext context, SubscribeController subCtrl) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Start date',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: kDarkColor,
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: subCtrl.startDate.value ?? now,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365)),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: kPrimaryGreen,
                          onPrimary: kWhite,
                          onSurface: kDarkColor,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) subCtrl.startDate.value = picked;
                },
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: kCardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 16, color: kPrimaryGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Obx(() {
                          final d = subCtrl.startDate.value;
                          return Text(
                            d == null
                                ? 'Select date'
                                : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: d == null ? kGreyColor : kDarkColor,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delivery time',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: kDarkColor,
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _showTimeSlotPicker(context, subCtrl),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: kCardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 16, color: kPrimaryGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Obx(() => Text(
                              SubscribeController.timeSlotLabels[
                                      subCtrl.selectedTimeSlot.value] ??
                                  subCtrl.selectedTimeSlot.value,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: kDarkColor,
                                fontWeight: FontWeight.w600,
                              ),
                            )),
                      ),
                      const Icon(Icons.keyboard_arrow_down,
                          size: 16, color: kGreyColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showTimeSlotPicker(BuildContext context, SubscribeController subCtrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select delivery time',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kDarkColor,
              ),
            ),
            const SizedBox(height: 12),
            ...SubscribeController.timeSlots.map(
              (slot) => Obx(() {
                final selected = subCtrl.selectedTimeSlot.value == slot;
                return GestureDetector(
                  onTap: () {
                    subCtrl.selectedTimeSlot.value = slot;
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kCardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? kPrimaryGreen : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      SubscribeController.timeSlotLabels[slot] ?? slot,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected ? kPrimaryGreen : kDarkColor,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryDetails(BuildContext context) {
    final addressCtrl = Get.find<AddressController>();
    return Obx(() {
      final address = addressCtrl.selectedAddress.value;
      return GestureDetector(
        onTap: () => _showAddressPicker(context, addressCtrl),
        child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Delivery details',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kDarkColor,
                  ),
                ),
                const Icon(Icons.edit_outlined, size: 18, color: kGreyColor),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.home_outlined, color: kPrimaryGreen, size: 18),
                const SizedBox(width: 8),
                Text(
                  address?.label ?? 'Home',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kDarkColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                address?.displayAddress ?? 'No address selected',
                style: GoogleFonts.inter(fontSize: 12, color: kGreyColor),
              ),
            ),
          ],
        ),
        ),
      );
    });
  }

  void _showAddressPicker(BuildContext context, AddressController addressCtrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Obx(() {
          final addresses = addressCtrl.addresses;
          if (addresses.isEmpty) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No saved addresses yet',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: kDarkColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add a delivery address from the Addresses screen first.',
                  style: GoogleFonts.inter(fontSize: 12, color: kGreyColor),
                  textAlign: TextAlign.center,
                ),
              ],
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select delivery address',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kDarkColor,
                ),
              ),
              const SizedBox(height: 12),
              ...addresses.map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AddressCard(
                    address: a,
                    selected: addressCtrl.selectedAddress.value?.id == a.id,
                    onSelect: () {
                      addressCtrl.selectAddress(a);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSubscribeButton(SubscribeController subCtrl) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      decoration: const BoxDecoration(
        color: kBgColor,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Obx(() {
        final isLoading = subCtrl.isLoading.value;
        return GestureDetector(
          onTap: isLoading
              ? null
              : () async {
                  final addressCtrl = Get.find<AddressController>();
                  final addressId = addressCtrl.selectedAddress.value?.id;
                  if (addressId == null) {
                    showAppSnackbar(
                      'Please select a delivery address first.',
                      title: 'Address required',
                      type: AppSnackbarType.error,
                    );
                    return;
                  }
                  final branchId = subCtrl.selectedBranchId.value;
                  if (branchId == null || branchId.isEmpty) {
                    showAppSnackbar(
                      'Please choose a restaurant to subscribe to.',
                      title: 'Restaurant required',
                      type: AppSnackbarType.error,
                    );
                    return;
                  }
                  final success = await subCtrl.subscribe(
                    branchId: branchId,
                    deliveryAddressId: addressId,
                  );
                  if (success) {
                    showAppSnackbar(
                      'Your subscription was created successfully.',
                      title: 'Subscribed',
                      type: AppSnackbarType.success,
                    );
                  } else {
                    showAppSnackbar(
                      subCtrl.errorMessage.value.isNotEmpty
                          ? subCtrl.errorMessage.value
                          : 'Please try again.',
                      title: 'Could not subscribe',
                      type: AppSnackbarType.error,
                    );
                  }
                },
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: isLoading ? kGreyColor : kPrimaryGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              isLoading
                  ? 'Processing...'
                  : 'Subscribe  •  ${subCtrl.isWeekly.value ? "Weekly" : "Monthly"}',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: kWhite,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _CycleTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CycleTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected ? kPrimaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? kWhite : kGreyColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _SubscribeItemTile extends StatelessWidget {
  final MenuItem item;
  const _SubscribeItemTile({super.key, required this.item});

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubscribeMealDetailScreen(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subCtrl = Get.find<SubscribeController>();
    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 68,
                height: 68,
                child: Image.network(
                  item.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(color: kLightGrey),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kDarkColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.nutrition.calories} kcal',
                    style: GoogleFonts.inter(fontSize: 11, color: kGreyColor),
                  ),
                  Obx(() {
                    final selection = subCtrl.selectionForMeal(item.id);
                    if (selection == null) return const SizedBox.shrink();
                    final sizeName = selection['sizeName']?.toString() ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        sizeName.isNotEmpty ? 'Added \u2022 $sizeName' : 'Added',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: kPrimaryGreen,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.price.toInt()} EGP',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kDarkColor,
                  ),
                ),
                const SizedBox(height: 6),
                Obx(() {
                  final added = subCtrl.selectionForMeal(item.id) != null;
                  return GestureDetector(
                    onTap: () => _openDetail(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: added ? kPrimaryGreen : kLightGrey,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        added ? 'Added' : 'View',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: added ? kWhite : kDarkColor,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
