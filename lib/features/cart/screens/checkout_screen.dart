import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/features/cart/controllers/cart_controller.dart';
import 'package:slyce/features/profile/controllers/address_controller.dart';
import 'package:slyce/widgets/address_card.dart';
import 'package:slyce/widgets/app_snackbar.dart';

/// Checkout step shown after the cart: delivery address, payment method
/// (cash / card), a payment summary and the final "Place Order" action.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _cartCtrl = Get.find<CartController>();
  final _addressCtrl = Get.find<AddressController>();

  // 'cash' or 'card'. No default — the customer must pick one before ordering.
  String? _paymentMethod;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: kBgColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Checkout',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: kDarkColor,
              ),
            ),
            Obx(() {
              final name = _cartCtrl.lastRestaurant.value?.name;
              if (name == null || name.isEmpty) {
                return const SizedBox.shrink();
              }
              return Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: kGreyColor,
                ),
              );
            }),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                _buildAddressCard(),
                const SizedBox(height: 16),
                _buildPaymentMethods(),
                const SizedBox(height: 16),
                _buildPaymentSummary(),
              ],
            ),
          ),
          _buildPlaceOrderButton(context),
        ],
      ),
    );
  }

  Widget _buildAddressCard() {
    return Obx(() {
      final address = _addressCtrl.selectedAddress.value;
      if (address == null) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kLightGrey),
          ),
          child: Text(
            'No delivery address selected',
            style: GoogleFonts.inter(fontSize: 13, color: kGreyColor),
          ),
        );
      }
      return AddressCard(address: address, selected: true);
    });
  }

  Widget _buildPaymentMethods() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pay with',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: kDarkColor,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kLightGrey),
          ),
          child: Column(
            children: [
              _PaymentOption(
                icon: Icons.add_circle_outline,
                label: 'Add new card',
                selected: _paymentMethod == 'card',
                onTap: () => setState(() => _paymentMethod = 'card'),
              ),
              const Divider(
                height: 1,
                color: kLightGrey,
                indent: 16,
                endIndent: 16,
              ),
              _PaymentOption(
                icon: Icons.payments_outlined,
                label: 'Cash',
                selected: _paymentMethod == 'cash',
                onTap: () => setState(() => _paymentMethod = 'cash'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSummary() {
    return Obx(() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment summary',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: kDarkColor,
              ),
            ),
            const SizedBox(height: 20),
            _SummaryRow(
              label: 'Subtotal',
              value: _formatPrice(_cartCtrl.subtotal),
            ),
            const SizedBox(height: 24),
            _SummaryRow(
              label: 'Total amount',
              value: _formatPrice(_cartCtrl.total),
              bold: true,
            ),
          ],
        ));
  }

  String _formatPrice(double amount) {
    final currency =
        _cartCtrl.currency.isNotEmpty ? _cartCtrl.currency : 'EGP';
    return '$currency ${amount.toStringAsFixed(2)}';
  }

  Widget _buildPlaceOrderButton(BuildContext context) {
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
        final isLoading = _cartCtrl.isCheckingOut.value;
        return GestureDetector(
          onTap: isLoading ? null : () => _placeOrder(context),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: isLoading ? kGreyColor : kPrimaryGreen,
              borderRadius: BorderRadius.circular(28),
            ),
            alignment: Alignment.center,
            child: Text(
              isLoading ? 'Processing...' : 'Place order',
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

  Future<void> _placeOrder(BuildContext context) async {
    final address = _addressCtrl.selectedAddress.value;
    final addressId = address?.id;
    if (address == null || addressId == null) {
      _showSnack(context, 'Please add a delivery address first.', isError: true);
      return;
    }
    final paymentMethod = _paymentMethod;
    if (paymentMethod == null) {
      _showSnack(context, 'Please select a payment method.', isError: true);
      return;
    }

    // Block the order when the chosen delivery address is outside the
    // restaurant's delivery zone (same rule as the subscription flow).
    final inZone = await _cartCtrl.isAddressInRestaurantZone(address);
    if (!context.mounted) return;
    if (!inZone) {
      final name = _cartCtrl.lastRestaurant.value?.name;
      _showSnack(
        context,
        (name == null || name.isEmpty)
            ? 'Your delivery location is outside this restaurant\'s delivery zone. Choose an address within its area to place the order.'
            : 'Your delivery location is outside $name\'s delivery zone. Choose an address within its area to place the order.',
        isError: true,
      );
      return;
    }

    final success = await _cartCtrl.checkout(
      deliveryAddressId: addressId,
      paymentMethod: paymentMethod,
    );

    if (!context.mounted) return;
    _showSnack(
      context,
      success ? 'Order placed successfully!' : _cartCtrl.errorMessage.value,
      isError: !success,
    );
    // Return to the cart (now empty) once the order is placed.
    if (success) Navigator.pop(context);
  }

  void _showSnack(BuildContext context, String message, {bool isError = false}) {
    showAppSnackbar(
      message,
      type: isError ? AppSnackbarType.error : AppSnackbarType.success,
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: kDarkColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kDarkColor,
                ),
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 22,
              color: selected ? kPrimaryGreen : kGreyColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: kDarkColor,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: kDarkColor,
          ),
        ),
      ],
    );
  }
}
