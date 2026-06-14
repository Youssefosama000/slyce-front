import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/features/order/controllers/order_controller.dart';
import 'package:slyce/features/order/models/order_model.dart';
import 'package:slyce/features/order/screens/order_details_screen.dart';
import 'package:slyce/widgets/empty_state_widget.dart';
import 'package:slyce/widgets/loading_widget.dart';

enum _OrderFilter { all, active, completed }

/// Order history list. Shows each order's restaurant name, order id, item
/// count, total price and status, wired to [OrderController].
///
/// Data comes from GET /v1/customers/:customerId/orders (`ordersHistory`).
/// The list response carries `orderItemsCount` but not the items themselves,
/// so per-item detail is loaded on the details screen.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final OrderController _ctrl = Get.isRegistered<OrderController>()
      ? Get.find<OrderController>()
      : Get.put(OrderController());

  _OrderFilter _filter = _OrderFilter.all;

  @override
  void initState() {
    super.initState();
    // Refetch on every entry so a freshly placed order shows up immediately
    // (the controller may have been created on an earlier visit).
    _ctrl.loadOrders();
  }

  List<OrderModel> _applyFilter(List<OrderModel> orders) {
    switch (_filter) {
      case _OrderFilter.active:
        return orders.where((o) => o.isActive).toList();
      case _OrderFilter.completed:
        return orders.where((o) => !o.isActive).toList();
      case _OrderFilter.all:
        return orders;
    }
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
        title: Text(
          'Orders',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: kDarkColor,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: Obx(() {
              if (_ctrl.isLoading.value && _ctrl.orders.isEmpty) {
                return const SlyceLoadingWidget(message: 'Loading orders...');
              }
              if (_ctrl.errorMessage.value.isNotEmpty &&
                  _ctrl.orders.isEmpty) {
                return SlyceEmptyWidget(
                  icon: Icons.receipt_long_outlined,
                  title: "Couldn't load orders",
                  subtitle: _ctrl.errorMessage.value,
                  actionLabel: 'Retry',
                  onAction: _ctrl.loadOrders,
                );
              }
              final orders = _applyFilter(_ctrl.orders);
              if (orders.isEmpty) {
                return const SlyceEmptyWidget(
                  icon: Icons.receipt_long_outlined,
                  title: 'No orders yet',
                  subtitle: 'Your past and active orders will show up here.',
                );
              }
              return RefreshIndicator(
                onRefresh: _ctrl.loadOrders,
                color: kPrimaryGreen,
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, i) => _OrderCard(
                    order: orders[i],
                    onViewDetails: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            OrderDetailsScreen(order: orders[i]),
                      ),
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

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _filterChip('All', _OrderFilter.all),
            const SizedBox(width: 10),
            _filterChip('Active', _OrderFilter.active),
            const SizedBox(width: 10),
            _filterChip('Completed', _OrderFilter.completed),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, _OrderFilter value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? kPrimaryGreen : kCardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? kPrimaryGreen : kLightGrey),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? kWhite : kDarkColor,
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onViewDetails;

  const _OrderCard({required this.order, required this.onViewDetails});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLightGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusBadge(status: order.status),
              const SizedBox(width: 10),
              if (order.createdAt != null)
                Expanded(
                  child: Text(
                    _formatDate(order.createdAt!),
                    style:
                        GoogleFonts.inter(fontSize: 12, color: kGreyColor),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (order.restaurantLogo != null &&
                  order.restaurantLogo!.isNotEmpty) ...[
                _buildLogo(order.restaurantLogo!, 48),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (order.restaurantName != null &&
                              order.restaurantName!.isNotEmpty)
                          ? order.restaurantName!
                          : 'Restaurant',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kDarkColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Order ID: ${order.id.isNotEmpty ? order.id : '--'}',
                      style:
                          GoogleFonts.inter(fontSize: 12, color: kGreyColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (order.displayItemCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${order.displayItemCount} item${order.displayItemCount == 1 ? '' : 's'}',
              style: GoogleFonts.inter(fontSize: 12, color: kGreyColor),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EGP ${order.displayTotal.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kDarkColor,
                ),
              ),
              GestureDetector(
                onTap: onViewDetails,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: kWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kLightGrey),
                  ),
                  child: Text(
                    'View details',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kDarkColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(String url, double size) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kLightGrey),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = dt.toLocal();
    final ampm = local.hour >= 12 ? 'pm' : 'am';
    var h12 = local.hour % 12;
    if (h12 == 0) h12 = 12;
    final min = local.minute.toString().padLeft(2, '0');
    return '${months[local.month - 1]} ${local.day} • $h12:$min$ampm';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color color;
    if (s.contains('deliver') || s.contains('complete')) {
      color = kPrimaryGreen;
    } else if (s.contains('cancel') ||
        s.contains('reject') ||
        s.contains('fail')) {
      color = const Color(0xFFE05B5B);
    } else {
      color = const Color(0xFFFF8A3D);
    }
    final label = status.isEmpty
        ? 'Unknown'
        : '${status[0].toUpperCase()}${status.substring(1)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
