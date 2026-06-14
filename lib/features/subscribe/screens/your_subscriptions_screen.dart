import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/features/subscribe/controllers/subscribe_controller.dart';
import 'package:slyce/features/subscribe/models/subscription_model.dart';

/// Read-only list of the customer's existing subscriptions
/// (GET /v1/subscriptions). Reached from Profile > "Your Subscriptions".
/// Refreshes on open, so a subscription shows up here right after it is
/// completed from the "Subscribe" tab.
class YourSubscriptionsScreen extends StatefulWidget {
  const YourSubscriptionsScreen({super.key});

  @override
  State<YourSubscriptionsScreen> createState() =>
      _YourSubscriptionsScreenState();
}

class _YourSubscriptionsScreenState extends State<YourSubscriptionsScreen> {
  final SubscribeController _subCtrl = Get.isRegistered<SubscribeController>()
      ? Get.find<SubscribeController>()
      : Get.put(SubscribeController());

  // false = show all subscriptions, true = show only active ones.
  bool _activeOnly = false;

  @override
  void initState() {
    super.initState();
    _subCtrl.loadSubscriptions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: kBgColor,
        elevation: 0,
        title: Text(
          'Subscriptions',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: kDarkColor,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _subCtrl.loadSubscriptions,
        color: kPrimaryGreen,
        child: Obx(() {
          if (_subCtrl.isLoadingSubscriptions.value &&
              _subCtrl.subscriptions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = _subCtrl.subscriptions.toList();
          final subs =
              _activeOnly ? all.where((s) => s.isActive).toList() : all;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _buildFilterChips(all.length),
              const SizedBox(height: 16),
              if (subs.isEmpty)
                _buildEmptyState()
              else
                ...subs.map((s) => _SubscriptionCard(sub: s)),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildFilterChips(int total) {
    return Row(
      children: [
        _chip(
          label: 'All Subscriptions',
          selected: !_activeOnly,
          count: total,
          onTap: () => setState(() => _activeOnly = false),
        ),
        const SizedBox(width: 10),
        _chip(
          label: 'Active',
          selected: _activeOnly,
          onTap: () => setState(() => _activeOnly = true),
        ),
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    int? count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? kPrimaryGreen : kWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: selected ? kPrimaryGreen : kLightGrey),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? kWhite : kDarkColor,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 7),
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? kWhite : kPrimaryGreen,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? kPrimaryGreen : kWhite,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 120),
      child: Column(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 56,
            color: kGreyColor,
          ),
          const SizedBox(height: 16),
          Text(
            _activeOnly
                ? 'You have no active subscriptions.'
                : 'You have no subscriptions yet.',
            style: GoogleFonts.inter(fontSize: 15, color: kGreyColor),
          ),
        ],
      ),
    );
  }
}

/// A summary card for one existing subscription, matching the Subscriptions
/// design: logo, next delivery + start date, item count, status badge and
/// total price.
class _SubscriptionCard extends StatelessWidget {
  final SubscriptionModel sub;
  const _SubscriptionCard({required this.sub});

  static String _fmtDate(DateTime? d) =>
      d == null ? '\u2014' : '${d.month}-${d.day}-${d.year}';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLightGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: logo + "Next Delivery" (and id) on the left, status badge
          // on the right. The badge sits on its own line so the price below
          // never collides with the text.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kLightGrey),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: sub.restaurantLogoUrl.isNotEmpty
                      ? Image.network(
                          sub.restaurantLogoUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => _logoPlaceholder(),
                        )
                      : _logoPlaceholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (sub.id.isNotEmpty) ...[
                      Text(
                        'id: ${sub.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            GoogleFonts.inter(fontSize: 9, color: kGreyColor),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      'Next Delivery: ${_fmtDate(sub.nextDelivery)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kDarkColor,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusBadge(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Start Date: ${_fmtDate(sub.startDate)}',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kDarkColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Items: ${sub.totalItems}',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kDarkColor,
            ),
          ),
          // Price on its own row, separated by a divider, so the big amount has
          // room to breathe and never overlaps the details.
          if (sub.totalPriceAmount > 0) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: kLightGrey),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Total',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kGreyColor,
                  ),
                ),
                const Spacer(),
                _priceLabel(),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _logoPlaceholder() => Container(
        width: 46,
        height: 46,
        color: kLightGrey,
        child: const Icon(Icons.storefront, size: 22, color: kGreyColor),
      );

  Widget _statusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: sub.isActive ? kPrimaryGreen.withValues(alpha: 0.14) : kLightGrey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        sub.status.isNotEmpty ? sub.status : (sub.isActive ? 'Active' : '\u2014'),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: sub.isActive ? kPrimaryGreen : kGreyColor,
        ),
      ),
    );
  }

  Widget _priceLabel() {
    if (sub.totalPriceAmount <= 0) return const SizedBox.shrink();
    final whole = sub.totalPriceAmount.floor();
    final cents = ((sub.totalPriceAmount - whole) * 100)
        .round()
        .toString()
        .padLeft(2, '0');
    final currency = sub.priceCurrency.isNotEmpty ? sub.priceCurrency : 'EGP';
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
              fontSize: 20,
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
}
