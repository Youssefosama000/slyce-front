import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:get/get.dart';
import 'package:slyce/features/home/controllers/home_controller.dart';
import 'package:slyce/features/home/repositories/menu_repository.dart';
import 'package:slyce/features/order/models/order_model.dart';
import 'package:slyce/features/order/repositories/order_repository.dart';

/// Plain order details: restaurant, order id, status, item breakdown and the
/// price summary. The orders-history list response does not include per-item
/// details, so this screen fetches the full order (GET
/// /v1/customers/:id/orders/:orderId) and merges its `orderItems` with the
/// summary already passed in from the list. No map / live tracking.
class OrderDetailsScreen extends StatefulWidget {
  final OrderModel order;
  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final OrderRepository _orderRepo = OrderRepository();
  final MenuRepository _menuRepo = MenuRepository();
  late OrderModel order = widget.order;
  bool _loadingItems = true;
  // Resolved meal photos keyed by lowercased meal name (order items only carry
  // a name, so images are matched against the nearby restaurants' menus).
  final Map<String, String> _imageByName = {};

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    if (widget.order.id.isEmpty) {
      setState(() => _loadingItems = false);
      return;
    }
    try {
      final full = await _orderRepo.getOrder(widget.order.id);
      if (!mounted) return;
      setState(() {
        // Merge: items / address / payment come from the details endpoint,
        // while restaurant name and total come from the list summary (the
        // details response doesn't carry them).
        order = OrderModel(
          id: full.id.isNotEmpty ? full.id : widget.order.id,
          status: full.status.isNotEmpty ? full.status : widget.order.status,
          items: full.items.isNotEmpty ? full.items : widget.order.items,
          total: widget.order.total > 0 ? widget.order.total : full.total,
          deliveryFee: widget.order.deliveryFee,
          deliveryAddressId:
              widget.order.deliveryAddressId ?? full.deliveryAddressId,
          deliveryAddress:
              full.deliveryAddress ?? widget.order.deliveryAddress,
          restaurantName: widget.order.restaurantName ?? full.restaurantName,
          restaurantLogo: widget.order.restaurantLogo ?? full.restaurantLogo,
          paymentMethod: full.paymentMethod ?? widget.order.paymentMethod,
          itemsCount: widget.order.itemsCount ?? full.itemsCount,
          createdAt: full.createdAt ?? widget.order.createdAt,
        );
        _loadingItems = false;
      });
      _resolveItemImages();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingItems = false);
    }
  }

  /// The backend's `orderItems` don't include meal images, so each row would
  /// otherwise show a placeholder. Resolve every item's photo from
  /// GET /meals/:id (by mealId) and patch the rows once loaded.
  Future<void> _resolveItemImages() async {
    final missing = order.items
        .where((it) => it.imageUrl == null || it.imageUrl!.isEmpty)
        .toList();
    if (missing.isEmpty) return;

    // The backend's `orderItems` only carry a meal name (no mealId, no image),
    // so we resolve each photo from the nearby restaurants' menus — the same
    // trusted source the search and home feeds use — matching on the name.
    final home = Get.isRegistered<HomeController>()
        ? Get.find<HomeController>()
        : Get.put(HomeController());

    // Check the order's own restaurant first, then the rest of the feed.
    final restaurants = [...home.restaurants];
    final orderRestaurant = (order.restaurantName ?? '').toLowerCase().trim();
    if (orderRestaurant.isNotEmpty) {
      restaurants.sort((a, b) {
        final am = a.name.toLowerCase().trim() == orderRestaurant ? 0 : 1;
        final bm = b.name.toLowerCase().trim() == orderRestaurant ? 0 : 1;
        return am - bm;
      });
    }

    bool allMatched() => missing.every((it) =>
        _imageByName.containsKey((it.mealName ?? '').toLowerCase().trim()));

    for (final r in restaurants) {
      if (allMatched()) break;
      var menu = r.menu;
      if (menu.isEmpty && r.id.isNotEmpty) {
        try {
          final resp = await _menuRepo.getMenu(r.id);
          menu = resp.allMeals.map((m) => m.toMenuItem()).toList();
        } catch (_) {
          menu = const [];
        }
      }
      for (final mi in menu) {
        final key = mi.name.toLowerCase().trim();
        if (mi.imageUrl.isNotEmpty && !_imageByName.containsKey(key)) {
          _imageByName[key] = mi.imageUrl;
        }
      }
    }

    if (!mounted || _imageByName.isEmpty) return;
    setState(() {
      order = OrderModel(
        id: order.id,
        status: order.status,
        items: order.items.map((it) {
          if (it.imageUrl != null && it.imageUrl!.isNotEmpty) return it;
          final url = _imageByName[(it.mealName ?? '').toLowerCase().trim()];
          if (url == null || url.isEmpty) return it;
          return OrderItemModel(
            id: it.id,
            mealId: it.mealId,
            mealName: it.mealName,
            sizeName: it.sizeName,
            quantity: it.quantity,
            price: it.price,
            imageUrl: url,
          );
        }).toList(),
        total: order.total,
        deliveryFee: order.deliveryFee,
        deliveryAddressId: order.deliveryAddressId,
        deliveryAddress: order.deliveryAddress,
        restaurantName: order.restaurantName,
        restaurantLogo: order.restaurantLogo,
        paymentMethod: order.paymentMethod,
        itemsCount: order.itemsCount,
        createdAt: order.createdAt,
        estimatedDelivery: order.estimatedDelivery,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final itemsSubtotal =
        order.items.fold<double>(0, (sum, it) => sum + it.totalPrice);

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
          'Order details',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: kDarkColor,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              _statusBadge(order.status),
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
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (order.restaurantLogo != null &&
                  order.restaurantLogo!.isNotEmpty) ...[
                _buildLogo(order.restaurantLogo!, 54),
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
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: kDarkColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Order ID: ${order.id.isNotEmpty ? order.id : '--'}',
                      style:
                          GoogleFonts.inter(fontSize: 13, color: kGreyColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (order.deliveryAddress != null &&
              order.deliveryAddress!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 15, color: kGreyColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.deliveryAddress!,
                    style:
                        GoogleFonts.inter(fontSize: 13, color: kGreyColor),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          _buildItemsCard(),
          const SizedBox(height: 14),
          _buildSummaryCard(itemsSubtotal),
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

  Widget _buildItemsCard() {
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
          Text(
            'Items',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kDarkColor,
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingItems && order.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: kPrimaryGreen),
                ),
              ),
            )
          else if (order.items.isEmpty)
            Text(
              'No item details available.',
              style: GoogleFonts.inter(fontSize: 13, color: kGreyColor),
            )
          else
            ...order.items.map(_buildItemRow),
        ],
      ),
    );
  }

  Widget _buildItemRow(OrderItemModel item) {
    final name = (item.mealName != null && item.mealName!.isNotEmpty)
        ? item.mealName!
        : 'Item';
    final size = (item.sizeName != null && item.sizeName!.isNotEmpty)
        ? ' • ${item.sizeName}'
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 46,
              height: 46,
              child: (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                  ? Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: kLightGrey,
                        child: const Icon(Icons.fastfood,
                            color: kGreyColor, size: 20),
                      ),
                    )
                  : Container(
                      color: kLightGrey,
                      child: const Icon(Icons.fastfood,
                          color: kGreyColor, size: 20),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: kPrimaryGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${item.quantity}x',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kPrimaryGreen,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$name$size',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kDarkColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'EGP ${item.totalPrice.toStringAsFixed(2)}',
            style: GoogleFonts.inter(fontSize: 13, color: kDarkColor),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double itemsSubtotal) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLightGrey),
      ),
      child: Column(
        children: [
          if (order.items.isNotEmpty)
            _summaryRow('Subtotal', itemsSubtotal),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: kLightGrey, height: 1),
          ),
          _summaryRow('Total', order.displayTotal, bold: true),
          if (order.paymentMethod != null &&
              order.paymentMethod!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: kGreyColor),
                ),
                Text(
                  order.paymentMethod!,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kDarkColor),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: bold ? kDarkColor : kGreyColor,
            ),
          ),
          Text(
            'EGP ${value.toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: kDarkColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
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
