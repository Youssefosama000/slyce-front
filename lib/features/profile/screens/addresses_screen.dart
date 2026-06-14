import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/features/profile/controllers/address_controller.dart';
import 'package:slyce/features/profile/models/address_model.dart';
import 'package:slyce/features/profile/screens/map_picker_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:slyce/widgets/loading_widget.dart';
import 'package:slyce/widgets/empty_state_widget.dart';
import 'package:slyce/widgets/address_card.dart';
import 'package:slyce/widgets/app_snackbar.dart';

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AddressController>();

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
          'My Addresses',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: kDarkColor,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (ctrl.isLoading.value && ctrl.addresses.isEmpty) {
                return const SlyceLoadingWidget(message: 'Loading addresses...');
              }

              if (ctrl.addresses.isEmpty) {
                return const SlyceEmptyWidget(
                  icon: Icons.location_off_outlined,
                  title: 'No saved addresses yet',
                  subtitle: 'Add a delivery address to get started',
                );
              }

              return RefreshIndicator(
                onRefresh: ctrl.loadAddresses,
                color: kPrimaryGreen,
                child: ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: ctrl.addresses.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => Obx(
                    () => AddressCard(
                      address: ctrl.addresses[i],
                      selected: ctrl.selectedAddress.value?.id ==
                          ctrl.addresses[i].id,
                      onSelect: () => ctrl.selectAddress(ctrl.addresses[i]),
                      onDelete: () =>
                          _confirmDelete(context, ctrl, ctrl.addresses[i]),
                    ),
                  ),
                ),
              );
            }),
          ),
          _buildAddButton(context, ctrl),
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, AddressController ctrl) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: GestureDetector(
        onTap: () => _showAddAddressSheet(context, ctrl),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: kPrimaryGreen,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, color: kWhite, size: 20),
              const SizedBox(width: 8),
              Text(
                'Add New Address',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kWhite,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Confirm with the user, then delete the address and surface the result so
  /// the action never silently "freezes".
  Future<void> _confirmDelete(
    BuildContext context,
    AddressController ctrl,
    AddressModel address,
  ) async {
    final id = address.id ?? '';
    if (id.isEmpty) {
      showAppSnackbar(
        'Cannot delete this address (missing id).',
        type: AppSnackbarType.error,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: kWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Delete address',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: kDarkColor,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${address.label}"?',
          style: GoogleFonts.inter(color: kGreyColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: kGreyColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await ctrl.deleteAddress(id);
    if (!context.mounted) return;
    showAppSnackbar(
      ok
          ? 'Address deleted.'
          : (ctrl.errorMessage.value.isNotEmpty
              ? ctrl.errorMessage.value
              : 'Failed to delete address.'),
      type: ok ? AppSnackbarType.success : AppSnackbarType.error,
    );
  }

  void _showAddAddressSheet(BuildContext context, AddressController ctrl) {
    final labelCtrl = TextEditingController();
    final streetCtrl = TextEditingController();
    final streetNumCtrl = TextEditingController();
    final areaCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final longCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New Address',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: kDarkColor,
                ),
              ),
              const SizedBox(height: 16),
              _SheetField(controller: labelCtrl, hint: 'Label (e.g. Home, Work)'),
              const SizedBox(height: 10),
              _SheetField(controller: streetCtrl, hint: 'Street name'),
              const SizedBox(height: 10),
              _SheetField(controller: streetNumCtrl, hint: 'Street number'),
              const SizedBox(height: 10),
              _SheetField(controller: areaCtrl, hint: 'Area'),
              const SizedBox(height: 10),
              _SheetField(controller: cityCtrl, hint: 'City'),
              const SizedBox(height: 10),
              _SheetField(controller: phoneCtrl, hint: 'Contact number'),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final hasExisting =
                      double.tryParse(latCtrl.text.trim()) != null &&
                          double.tryParse(longCtrl.text.trim()) != null;
                  final picked = await Navigator.push<LatLng>(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => MapPickerScreen(
                        initial: hasExisting
                            ? LatLng(
                                double.parse(latCtrl.text.trim()),
                                double.parse(longCtrl.text.trim()),
                              )
                            : null,
                      ),
                    ),
                  );
                  if (picked != null) {
                    latCtrl.text = picked.latitude.toStringAsFixed(6);
                    longCtrl.text = picked.longitude.toStringAsFixed(6);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: kCardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kPrimaryGreen),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.map_outlined,
                          color: kPrimaryGreen, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Pick location on map',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kPrimaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pick your delivery location on the map above.',
                style: GoogleFonts.inter(fontSize: 11, color: kGreyColor),
              ),
              const SizedBox(height: 20),
              Obx(() => GestureDetector(
                    onTap: ctrl.isSaving.value
                        ? null
                        : () async {
                            if (labelCtrl.text.trim().isEmpty) {
                              showAppSnackbar(
                                'Enter a label (e.g. Home, Work).',
                                title: 'Label required',
                                type: AppSnackbarType.error,
                              );
                              return;
                            }
                            if (streetCtrl.text.trim().isEmpty) {
                              showAppSnackbar(
                                'Enter a street name.',
                                title: 'Street required',
                                type: AppSnackbarType.error,
                              );
                              return;
                            }
                            // Coordinates are user-provided (no hard-coded
                            // location). They drive the nearby-restaurants feed.
                            final lat = double.tryParse(latCtrl.text.trim());
                            final lng = double.tryParse(longCtrl.text.trim());
                            if (lat == null || lng == null) {
                              showAppSnackbar(
                                'Tap "Pick location on map" to set your delivery point.',
                                title: 'Location required',
                                type: AppSnackbarType.error,
                              );
                              return;
                            }
                            final address = AddressModel(
                              label: labelCtrl.text.trim(),
                              streetName: streetCtrl.text.trim(),
                              streetNumber: streetNumCtrl.text.trim(),
                              area: areaCtrl.text.trim(),
                              city: cityCtrl.text.trim(),
                              latitude: lat,
                              longitude: lng,
                              contactNumber: phoneCtrl.text.trim().isEmpty
                                  ? null
                                  : phoneCtrl.text.trim(),
                            );
                            final success = await ctrl.createAddress(address);
                            if (!ctx.mounted) return;
                            if (success) {
                              Navigator.pop(ctx);
                              showAppSnackbar(
                                'Address added.',
                                type: AppSnackbarType.success,
                              );
                            } else {
                              showAppSnackbar(
                                ctrl.errorMessage.value.isNotEmpty
                                    ? ctrl.errorMessage.value
                                    : 'Failed to add address. Please try again.',
                                title: 'Could not add address',
                                type: AppSnackbarType.error,
                              );
                            }
                          },
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: ctrl.isSaving.value ? kGreyColor : kPrimaryGreen,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        ctrl.isSaving.value ? 'Saving...' : 'Save Address',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: kWhite,
                        ),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  const _SheetField({
    required this.controller,
    required this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 14, color: kDarkColor),
      decoration: InputDecoration(hintText: hint),
    );
  }
}


