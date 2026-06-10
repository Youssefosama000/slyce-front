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
      };
}


