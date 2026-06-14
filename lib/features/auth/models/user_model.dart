/// User model returned from login / profile endpoints.
class UserModel {
  final String? id;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phoneNumber;
  final String? gender;
  final String? activityLevel;
  final String? birthDay;
  final String? accessToken;
  final String? refreshToken;
  final String? role;

  /// Profile fields used by the AI recommendation endpoint. These are not part
  /// of the login token — they come from GET /customers/me after onboarding.
  final double? heightCm;
  final List<String> allergies;
  final List<String> dietPreferences;

  const UserModel({
    this.id,
    this.firstName,
    this.lastName,
    this.email,
    this.phoneNumber,
    this.gender,
    this.activityLevel,
    this.birthDay,
    this.accessToken,
    this.refreshToken,
    this.role,
    this.heightCm,
    this.allergies = const [],
    this.dietPreferences = const [],
  });

  String get fullName =>
      '${firstName ?? ''} ${lastName ?? ''}'.trim().isEmpty
          ? 'User'
          : '${firstName ?? ''} ${lastName ?? ''}'.trim();

  String get initials {
    final f = (firstName ?? '').isNotEmpty ? firstName![0].toUpperCase() : '';
    final l = (lastName ?? '').isNotEmpty ? lastName![0].toUpperCase() : '';
    return '$f$l'.isEmpty ? 'U' : '$f$l';
  }

  UserModel copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
    String? gender,
    String? activityLevel,
    String? birthDay,
    String? accessToken,
    String? refreshToken,
    String? role,
    double? heightCm,
    List<String>? allergies,
    List<String>? dietPreferences,
  }) {
    return UserModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      gender: gender ?? this.gender,
      activityLevel: activityLevel ?? this.activityLevel,
      birthDay: birthDay ?? this.birthDay,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      role: role ?? this.role,
      heightCm: heightCm ?? this.heightCm,
      allergies: allergies ?? this.allergies,
      dietPreferences: dietPreferences ?? this.dietPreferences,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Handle both flat response and nested data structures
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return UserModel(
      id: data['id']?.toString() ?? data['customerId']?.toString(),
      firstName: data['firstName']?.toString() ?? data['first_name']?.toString(),
      lastName: data['lastName']?.toString() ?? data['last_name']?.toString(),
      email: data['email']?.toString(),
      phoneNumber: data['phoneNumber']?.toString() ?? data['phone_number']?.toString(),
      gender: data['gender']?.toString(),
      activityLevel: data['activityLevel']?.toString() ?? data['activity_level']?.toString(),
      birthDay: data['birthDay']?.toString() ?? data['birthday']?.toString(),
      accessToken: data['accessToken']?.toString() ??
          data['access_token']?.toString() ??
          json['accessToken']?.toString() ??
          json['access_token']?.toString() ??
          json['token']?.toString(),
      refreshToken: data['refreshToken']?.toString() ??
          data['refresh_token']?.toString() ??
          json['refreshToken']?.toString() ??
          json['refresh_token']?.toString(),
      role: data['role']?.toString() ??
          data['roleName']?.toString() ??
          json['role']?.toString(),
      heightCm: _toDouble(
          data['heightCm'] ?? data['height_cm'] ?? data['height']),
      allergies: _stringList(data['allergens'] ??
          data['allergies'] ??
          data['allergenIds'] ??
          data['allergen_ids']),
      dietPreferences: _stringList(data['dietPreferences'] ??
          data['diet_preferences'] ??
          data['dietPrefs'] ??
          data['diet_prefs'] ??
          data['foodPreferences'] ??
          data['food_preferences'] ??
          data['dietPreferenceIds']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phoneNumber': phoneNumber,
        'gender': gender,
        'activityLevel': activityLevel,
        'birthDay': birthDay,
        'role': role,
        'heightCm': heightCm,
        'allergies': allergies,
        'dietPreferences': dietPreferences,
      };

  /// Parse a possibly-stringified number into a double.
  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  /// Flatten a list that may contain plain strings or {id,name} objects into a
  /// list of display strings (preferring names, falling back to ids).
  static List<String> _stringList(dynamic v) {
    if (v is! List) return const [];
    final out = <String>[];
    for (final e in v) {
      if (e == null) continue;
      if (e is Map) {
        final s = (e['name'] ??
                e['displayName'] ??
                e['title'] ??
                e['label'] ??
                e['id'] ??
                e['allergenId'] ??
                e['dietPreferenceId'] ??
                '')
            .toString();
        if (s.isNotEmpty) out.add(s);
      } else {
        final s = e.toString();
        if (s.isNotEmpty) out.add(s);
      }
    }
    return out;
  }
}


