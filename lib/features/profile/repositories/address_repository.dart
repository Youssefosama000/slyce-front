import 'package:slyce/core/constants/api_endpoints.dart';
import 'package:slyce/core/network/dio_client.dart';
import 'package:slyce/features/profile/models/address_model.dart';

/// Repository for address management API calls.
class AddressRepository {
  final _client = DioClient.instance;

  /// List all customer addresses.
  Future<List<AddressModel>> getAddresses() async {
    final response = await _client.get(ApiEndpoints.addresses);
    final data = response.data;

    List items;
    if (data is List) {
      items = data;
    } else if (data is Map) {
      items = (data['customerAddresses'] ??
              data['data'] ??
              data['addresses'] ??
              []) as List;
    } else {
      items = [];
    }

    return items
        .map((e) => AddressModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get a specific address by ID.
  Future<AddressModel> getAddress(String id) async {
    final response = await _client.get(ApiEndpoints.addressById(id));
    if (response.data == null || response.data is! Map<String, dynamic>) {
      return AddressModel(label: 'Address');
    }
    final data = response.data as Map<String, dynamic>;
    final addressData = data['data'] ?? data;
    return AddressModel.fromJson(addressData as Map<String, dynamic>);
  }

  /// Create a new address.
  Future<AddressModel> createAddress(AddressModel address) async {
    final response = await _client.post(
      ApiEndpoints.addresses,
      data: address.toJson(),
    );
    if (response.data == null || response.data is! Map<String, dynamic>) {
      return address;
    }
    final data = response.data as Map<String, dynamic>;
    final addressData = data['data'] ?? data;
    return AddressModel.fromJson(addressData as Map<String, dynamic>);
  }

  /// Update an existing address by ID.
  Future<AddressModel> updateAddress(String id, AddressModel address) async {
    final response = await _client.put(
      ApiEndpoints.addressById(id),
      data: address.toJson(),
    );
    if (response.data == null || response.data is! Map<String, dynamic>) {
      return address;
    }
    final data = response.data as Map<String, dynamic>;
    final addressData = data['data'] ?? data;
    return AddressModel.fromJson(addressData as Map<String, dynamic>);
  }

  /// Delete an address by ID.
  Future<void> deleteAddress(String id) async {
    await _client.delete(ApiEndpoints.addressById(id));
  }
}


