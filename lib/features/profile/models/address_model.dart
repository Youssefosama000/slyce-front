/// Address model matching the backend's address schema.
class AddressModel {
  final String? id;
  final String label;
  final String? streetName;
  final String? streetNumber;
  final String? area;
  final String? city;
  final double? latitude;
  final double? longitude;
  final String? contactNumber;

  const AddressModel({
    this.id,
    required this.label,
    this.streetName,
    this.streetNumber,
    this.area,
    this.city,
    this.latitude,
    this.longitude,
    this.contactNumber,
  });

  /// Formatted display string.
  String get displayAddress {
    final parts = <String>[
      if (streetNumber != null && streetNumber!.isNotEmpty) streetNumber!,
      if (streetName != null && streetName!.isNotEmpty) streetName!,
      if (area != null && area!.isNotEmpty) area!,
      if (city != null && city!.isNotEmpty) city!,
    ];
    return parts.isNotEmpty ? parts.join(', ') : 'No address details';
  }

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['addressId']?.toString() ?? json['id']?.toString(),
      label: json['label']?.toString() ?? 'Address',
      streetName: json['streetName']?.toString() ?? json['street_name']?.toString(),
      streetNumber: json['streetNumber']?.toString() ?? json['street_number']?.toString(),
      area: json['area']?.toString(),
      city: json['city']?.toString(),
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      contactNumber: json['contactNumber']?.toString() ??
          json['phoneNumber']?.toString() ??
          json['contact_number']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final phone = normalizePhone(contactNumber);
    final map = <String, dynamic>{
      'label': label,
      if (streetName != null) 'streetName': streetName,
      if (streetNumber != null) 'streetNumber': streetNumber,
      if (area != null) 'area': area,
      if (city != null) 'city': city,
      // Backend requires coordinates; always send them (default to 0 if unset).
      'latitude': latitude ?? 0.0,
      'longitude': longitude ?? 0.0,
      if (phone != null) 'contactNumber': phone,
    };
    return map;
  }

  /// Normalise an Egyptian phone number to E.164 format (e.g. "+201013607615").
  ///
  /// The backend rejects local formats like "01013607615" (HTTP 500), so we
  /// convert any local/00-prefixed number to the international "+20" form.
  static String? normalizePhone(String? raw) {
    if (raw == null) return null;
    // Keep digits and a leading +.
    var s = raw.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (s.isEmpty) return null;
    if (s.startsWith('+')) return s;
    if (s.startsWith('00')) return '+${s.substring(2)}';
    if (s.startsWith('0')) return '+20${s.substring(1)}';
    // Bare local number without a leading zero (e.g. "1013607615").
    if (s.startsWith('20')) return '+$s';
    return '+20$s';
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}


