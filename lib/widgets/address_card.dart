import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/features/profile/models/address_model.dart';

/// Shared address card used everywhere an address appears (addresses list,
/// checkout, subscription, delivery pickers) so every address looks the same:
/// a bold label, the formatted address, and a "Selected" / "Select" pill, with
/// an optional red delete action.
class AddressCard extends StatelessWidget {
  final AddressModel address;
  final bool selected;

  /// Tapping the "Select" pill. When null and [selected] is true the card just
  /// shows the selected state with no action.
  final VoidCallback? onSelect;

  /// Tapping the delete icon. The icon is hidden when null.
  final VoidCallback? onDelete;

  const AddressCard({
    super.key,
    required this.address,
    this.selected = false,
    this.onSelect,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLightGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  address.label,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kDarkColor,
                  ),
                ),
              ),
              if (onDelete != null)
                GestureDetector(
                  onTap: onDelete,
                  behavior: HitTestBehavior.opaque,
                  child: const Icon(
                    Icons.delete_outline,
                    size: 22,
                    color: Colors.redAccent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            address.displayAddress,
            style: GoogleFonts.inter(fontSize: 13, color: kGreyColor),
          ),
          if (address.contactNumber != null &&
              address.contactNumber!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              address.contactNumber!,
              style: GoogleFonts.inter(fontSize: 12, color: kGreyColor),
            ),
          ],
          const SizedBox(height: 12),
          _buildStatusPill(),
        ],
      ),
    );
  }

  Widget _buildStatusPill() {
    if (selected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: kPrimaryGreen,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 14, color: kWhite),
            const SizedBox(width: 6),
            Text(
              'Selected',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kWhite,
              ),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: onSelect,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kLightGrey),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.radio_button_unchecked,
                size: 14, color: kGreyColor),
            const SizedBox(width: 6),
            Text(
              'Select',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kGreyColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
