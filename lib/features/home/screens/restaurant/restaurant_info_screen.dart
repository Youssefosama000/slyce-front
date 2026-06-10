import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/network/api_exceptions.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/features/home/models/restaurant.dart';
import 'package:slyce/features/home/repositories/menu_repository.dart';

class RestaurantInfoScreen extends StatefulWidget {
  final Restaurant restaurant;
  const RestaurantInfoScreen({super.key, required this.restaurant});

  @override
  State<RestaurantInfoScreen> createState() => _RestaurantInfoScreenState();
}

class _RestaurantInfoScreenState extends State<RestaurantInfoScreen> {
  final MenuRepository _repo = MenuRepository();

  bool _loading = true;
  String _address = '';
  String _phone = '';
  List<OpeningHours> _hours = const [];

  @override
  void initState() {
    super.initState();
    // Seed with anything the restaurant already carries (usually empty when it
    // came from the `nearby` feed, which has no address/phone/hours).
    _address = widget.restaurant.location;
    _phone = widget.restaurant.phone;
    _hours = widget.restaurant.openingHours;
    _loadDetails();
  }

  /// Fetch branch details (city/area/phone/workingHours) so the info screen
  /// shows real data instead of empty placeholders. The `nearby` endpoint
  /// doesn't return these fields, so we resolve them from
  /// GET /branches/:id/details using the branch id.
  Future<void> _loadDetails() async {
    final branchId = widget.restaurant.primaryBranchId;
    if (branchId == null || branchId.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    try {
      final branch = await _repo.getBranchDetails(branchId);
      if (!mounted) return;
      setState(() {
        if (branch.address.isNotEmpty) _address = branch.address;
        if (branch.phone != null && branch.phone!.isNotEmpty) {
          _phone = branch.phone!;
        }
        if (branch.openingHours.isNotEmpty) _hours = branch.openingHours;
        _loading = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
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
          widget.restaurant.name,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: kDarkColor,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _InfoCard(
            icon: Icons.location_on_outlined,
            title: _valueOrPlaceholder(_address),
            subtitle: 'Address',
          ),
          const SizedBox(height: 12),
          _buildOpeningHoursCard(),
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.phone_outlined,
            title: _valueOrPlaceholder(_phone),
            subtitle: 'Phone',
          ),
          if (widget.restaurant.branches.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildBranchesCard(),
          ],
        ],
      ),
    );
  }

  String _valueOrPlaceholder(String value) {
    if (value.isNotEmpty) return value;
    return _loading ? 'Loading\u2026' : 'Not available';
  }

  Widget _buildBranchesCard() {
    final branches = widget.restaurant.branches;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront_outlined,
                  color: kPrimaryGreen, size: 20),
              const SizedBox(width: 10),
              Text(
                'Branches',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kDarkColor,
                ),
              ),
              const Spacer(),
              Text(
                '${branches.length}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kPrimaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...branches.map(
            (b) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined,
                      color: kGreyColor, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.name,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kDarkColor,
                          ),
                        ),
                        if (b.address.isNotEmpty)
                          Text(
                            b.address,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: kGreyColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpeningHoursCard() {
    final isOpen = _isOpenNow();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, color: kPrimaryGreen, size: 20),
              const SizedBox(width: 10),
              Text(
                'Opening hours',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kDarkColor,
                ),
              ),
              const Spacer(),
              if (isOpen != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isOpen ? kPrimaryGreen : kGreyColor)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isOpen ? 'Open' : 'Closed',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isOpen ? kPrimaryGreen : kGreyColor,
                    ),
                  ),
                ),
            ],
          ),
          if (_hours.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _loading ? 'Loading\u2026' : 'Not available',
              style: GoogleFonts.inter(fontSize: 13, color: kGreyColor),
            ),
          ] else ...[
            const SizedBox(height: 12),
            ..._hours.map(
              (h) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        h.day,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kDarkColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_fmtTime(h.open)} \u2013 ${_fmtTime(h.close)}',
                      style:
                          GoogleFonts.inter(fontSize: 13, color: kGreyColor),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Returns true/false if open/closed can be determined for today, or null if
  /// there isn't enough data to decide (so the badge is hidden).
  bool? _isOpenNow() {
    if (_hours.isEmpty) return null;
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final now = DateTime.now();
    final todayName = days[now.weekday - 1];
    OpeningHours? today;
    for (final h in _hours) {
      if (h.day.toLowerCase() == todayName.toLowerCase()) {
        today = h;
        break;
      }
    }
    if (today == null) return false; // not listed today => closed
    final open = _toMinutes(today.open);
    final close = _toMinutes(today.close);
    if (open == null || close == null) return null;
    final nowMinutes = now.hour * 60 + now.minute;
    return nowMinutes >= open && nowMinutes <= close;
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

  String _fmtTime(String time) {
    if (time.isEmpty) return '--';
    final parts = time.split(':');
    if (parts.length < 2) return time;
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: kPrimaryGreen, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kDarkColor,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 12, color: kGreyColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
