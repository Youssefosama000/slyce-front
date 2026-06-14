import 'package:get/get.dart';
import 'package:slyce/core/network/api_exceptions.dart';
import 'package:slyce/features/profile/models/address_model.dart';
import 'package:slyce/features/profile/repositories/address_repository.dart';

/// GetX controller for address management.
class AddressController extends GetxController {
  final _addressRepo = AddressRepository();

  // ── Observables ─────────────────────────────────────────────────────
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = ''.obs;
  final addresses = <AddressModel>[].obs;
  final selectedAddress = Rxn<AddressModel>();

  @override
  void onInit() {
    super.onInit();
    loadAddresses();
  }

  /// Load all addresses from API.
  Future<void> loadAddresses() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      addresses.value = await _addressRepo.getAddresses();
      if (addresses.isNotEmpty && selectedAddress.value == null) {
        selectedAddress.value = addresses.first;
      }
    } on ApiException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'Failed to load addresses.';
    } finally {
      isLoading.value = false;
    }
  }

  /// Create a new address.
  Future<bool> createAddress(AddressModel address) async {
    isSaving.value = true;
    errorMessage.value = '';

    try {
      final created = await _addressRepo.createAddress(address);
      // The POST returns 201 with an empty body (no id). Without a real
      // addressId the new address can't be deleted or selected until a manual
      // refresh, so re-sync from the server when the id is missing.
      if (created.id == null || created.id!.isEmpty) {
        await loadAddresses();
      } else {
        addresses.add(created);
        if (selectedAddress.value == null) {
          selectedAddress.value = created;
        }
      }
      return true;
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (_) {
      errorMessage.value = 'Failed to save address.';
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /// Update an existing address.
  Future<bool> updateAddress(String id, AddressModel address) async {
    isSaving.value = true;
    errorMessage.value = '';

    try {
      final updated = await _addressRepo.updateAddress(id, address);
      final index = addresses.indexWhere((a) => a.id == id);
      if (index != -1) addresses[index] = updated;
      if (selectedAddress.value?.id == id) selectedAddress.value = updated;
      return true;
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (_) {
      errorMessage.value = 'Failed to update address.';
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /// Delete an address by ID via API.
  Future<bool> deleteAddress(String id) async {
    errorMessage.value = '';

    try {
      await _addressRepo.deleteAddress(id);
      // Reassign the list (instead of removeWhere) so the Obx list updates
      // immediately, without waiting for a manual pull-to-refresh.
      addresses.assignAll(addresses.where((a) => a.id != id).toList());
      if (selectedAddress.value?.id == id) {
        selectedAddress.value = addresses.isNotEmpty ? addresses.first : null;
      }
      return true;
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (_) {
      errorMessage.value = 'Failed to delete address.';
      return false;
    }
  }

  /// Select an address for delivery.
  void selectAddress(AddressModel address) {
    selectedAddress.value = address;
  }
}


