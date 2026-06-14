import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/features/cart/controllers/cart_controller.dart';
import 'package:slyce/features/cart/models/cart_model.dart';
import 'package:slyce/features/cart/screens/checkout_screen.dart';
import 'package:slyce/features/home/screens/restaurant/restaurant_menu_screen.dart';
import 'package:slyce/features/home/controllers/nav_controller.dart';
import 'package:slyce/features/profile/controllers/address_controller.dart';
import 'package:slyce/widgets/address_card.dart';
import 'package:slyce/widgets/loading_widget.dart';
import 'package:slyce/widgets/empty_state_widget.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cartCtrl = Get.find<CartController>();

    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: kBgColor,
        elevation: 0,
        title: Text(
          'Cart',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: kDarkColor,
          ),
        ),
        actions: [
          Obx(() {
            if (cartCtrl.items.isEmpty) return const SizedBox.shrink();
            return TextButton.icon(
              onPressed: () => _confirmClearCart(cartCtrl),
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Colors.redAccent,
              ),
              label: Text(
                'Clear',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.redAccent,
                ),
              ),
            );
          }),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() {
        if (cartCtrl.isLoading.value && cartCtrl.items.isEmpty) {
          return const SlyceLoadingWidget(message: 'Loading your cart...');
        }
        if (cartCtrl.items.isEmpty) {
          return const SlyceEmptyWidget(
            icon: Icons.shopping_bag_outlined,
            title: 'Your cart is empty',
            subtitle: 'Add items from a restaurant to get started',
          );
        }
        return _buildCartBody(context, cartCtrl);
      }),
    );
  }

  Widget _buildCartBody(BuildContext context, CartController cartCtrl) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              _buildDeliveryDetails(context),
              const SizedBox(height: 16),
              _buildItemDetails(cartCtrl),
              const SizedBox(height: 16),
              _buildPriceSummary(cartCtrl),
            ],
          ),
        ),
        _buildBottomBar(context, cartCtrl),
      ],
    );
  }

  Widget _buildDeliveryDetails(BuildContext context) {
    final addressCtrl = Get.find<AddressController>();
    return Obx(() {
      final address = addressCtrl.selectedAddress.value;
      return GestureDetector(
        onTap: () => _showAddressPicker(context, addressCtrl),
        behavior: HitTestBehavior.opaque,
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
            const SizedBox(height: 12),
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

  /// Bottom sheet that lets the customer switch the delivery address from the
  /// cart, mirroring the subscription flow's address picker.
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

  Widget _buildItemDetails(CartController cartCtrl) {
    return Obx(() => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Item Details',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kDarkColor,
                ),
              ),
              const SizedBox(height: 16),
              ...cartCtrl.items
                  .map((item) => _buildCartItemCard(cartCtrl, item)),
            ],
          ),
        ));
  }

  /// A single cart line, matching the Cart design: image, name + size badge,
  /// optional description, an Edit action, a green quantity stepper and the
  /// green EGP price.
  Widget _buildCartItemCard(CartController cartCtrl, CartItemModel item) {
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;
    final hasDescription =
        item.description != null && item.description!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: hasImage
                ? Image.network(
                    item.imageUrl!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _imagePlaceholder(),
                  )
                : _imagePlaceholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        item.mealName ?? 'Meal',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kDarkColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.sizeName != null && item.sizeName!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _sizeBadge(item.sizeName!),
                    ],
                  ],
                ),
                if (hasDescription) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description!.trim(),
                    style:
                        GoogleFonts.inter(fontSize: 11, color: kGreyColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _editItem(cartCtrl, item),
                  child: Text(
                    'Edit',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kPrimaryGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _qtyStepper(cartCtrl, item),
              const SizedBox(height: 12),
              _priceTag(item),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
        width: 64,
        height: 64,
        color: kLightGrey,
        child: const Icon(Icons.fastfood, color: kGreyColor),
      );

  Widget _sizeBadge(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: kPrimaryGreen,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: kWhite,
          ),
        ),
      );

  Widget _qtyStepper(CartController cartCtrl, CartItemModel item) {
    final mealId = item.mealId;
    final sizeId = item.sizeId;
    final canEdit = mealId != null && sizeId != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kPrimaryGreen,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: !canEdit
                ? null
                : () {
                    if (item.quantity <= 1) {
                      cartCtrl.removeItem(mealId: mealId!, sizeId: sizeId!);
                    } else {
                      cartCtrl.updateItem(
                          mealId: mealId!,
                          sizeId: sizeId!,
                          quantity: item.quantity - 1);
                    }
                  },
            child: const Icon(Icons.remove, color: kWhite, size: 18),
          ),
          const SizedBox(width: 14),
          Text(
            '${item.quantity}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kWhite,
            ),
          ),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: !canEdit
                ? null
                : () => cartCtrl.updateItem(
                    mealId: mealId!,
                    sizeId: sizeId!,
                    quantity: item.quantity + 1),
            child: const Icon(Icons.add, color: kWhite, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _priceTag(CartItemModel item) {
    final amount = item.price;
    final whole = amount.floor();
    final cents =
        ((amount - whole) * 100).round().toString().padLeft(2, '0');
    final currency = item.currency.isNotEmpty ? item.currency : 'EGP';
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$currency ',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: kPrimaryGreen,
            ),
          ),
          TextSpan(
            text: '$whole',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: kPrimaryGreen,
            ),
          ),
          TextSpan(
            text: '.$cents',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kPrimaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  void _editItem(CartController cartCtrl, CartItemModel item) {
    final mealId = item.mealId;
    final sizeId = item.sizeId;
    if (mealId == null || sizeId == null) return;
    Get.dialog(
      AlertDialog(
        backgroundColor: kWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          item.mealName ?? 'Item',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kDarkColor,
          ),
        ),
        content: Text(
          'Remove this item from your cart?',
          style: GoogleFonts.inter(fontSize: 13, color: kGreyColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: kGreyColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              cartCtrl.removeItem(mealId: mealId!, sizeId: sizeId!);
            },
            child: Text(
              'Remove',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearCart(CartController cartCtrl) {
    Get.dialog(
      AlertDialog(
        backgroundColor: kWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Clear cart',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kDarkColor,
          ),
        ),
        content: Text(
          'Remove all items from your cart? This cannot be undone.',
          style: GoogleFonts.inter(fontSize: 13, color: kGreyColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: kGreyColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              cartCtrl.clearCart();
            },
            child: Text(
              'Clear all',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSummary(CartController cartCtrl) {
    return Obx(() => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _PriceRow(label: 'Subtotal', value: '${cartCtrl.subtotal.toInt()} ${cartCtrl.currency}'.trim()),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(color: kLightGrey, height: 1),
              ),
              _PriceRow(label: 'Total', value: '${cartCtrl.total.toInt()} ${cartCtrl.currency}'.trim(), bold: true),
            ],
          ),
        ));
  }

  Widget _buildBottomBar(BuildContext context, CartController cartCtrl) {
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
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _addItems(context, cartCtrl),
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: kLightGrey),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Add Items',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kDarkColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CheckoutScreen()),
              ),
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: kPrimaryGreen,
                  borderRadius: BorderRadius.circular(28),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Checkout',
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

  /// "Add Items" returns the customer to the restaurant they last added from.
  void _addItems(BuildContext context, CartController cartCtrl) {
    final restaurant = cartCtrl.lastRestaurant.value;
    if (restaurant != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantMenuScreen(restaurant: restaurant),
        ),
      );
      return;
    }
    // No remembered restaurant (e.g. after a fresh launch): jump to the Home
    // tab so the customer can browse restaurants and add items, instead of
    // showing a dead-end message that covers the action buttons.
    Get.find<NavController>().goToTab(NavController.homeTab);
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _PriceRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: bold ? kDarkColor : kGreyColor,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: kDarkColor,
          ),
        ),
      ],
    );
  }
}


