class AuthHealth {
  AuthHealth({required this.status});

  final String status;
}

class LoginRequest {
  LoginRequest({
    required this.identifier,
    required this.password,
    this.otpCode,
  });

  final String identifier;
  final String password;
  final String? otpCode;

  Map<String, dynamic> toJson() {
    return {
      'identifier': identifier,
      'password': password,
      if (otpCode != null && otpCode!.isNotEmpty) 'otpCode': otpCode,
    };
  }
}

class RefreshRequest {
  RefreshRequest({required this.refreshToken});

  final String refreshToken;

  Map<String, dynamic> toJson() {
    return {'refreshToken': refreshToken};
  }
}

class AuthTokenBundle {
  AuthTokenBundle({
    required this.tokenType,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String tokenType;
  String accessToken;
  String refreshToken;
  int expiresIn;
  DateTime _receivedAt = DateTime.now();

  bool get needsRefresh => DateTime.now().isAfter(
      _receivedAt.add(Duration(seconds: expiresIn - 60)));

  void replaceWith(AuthTokenBundle updated) {
    accessToken = updated.accessToken;
    refreshToken = updated.refreshToken;
    expiresIn = updated.expiresIn;
    _receivedAt = updated._receivedAt;
  }

  factory AuthTokenBundle.fromJson(Map<String, dynamic> json) {
    return AuthTokenBundle(
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 0,
    );
  }
}

class DashboardSummary {
  DashboardSummary({
    required this.userCount,
    required this.personCount,
    required this.circleCount,
    required this.relationshipCount,
    required this.permissionCount,
  });

  final int userCount;
  final int personCount;
  final int circleCount;
  final int relationshipCount;
  final int permissionCount;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      userCount: (json['userCount'] as num?)?.toInt() ?? 0,
      personCount: (json['personCount'] as num?)?.toInt() ?? 0,
      circleCount: (json['circleCount'] as num?)?.toInt() ?? 0,
      relationshipCount: (json['relationshipCount'] as num?)?.toInt() ?? 0,
      permissionCount: (json['permissionCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class RegisterUserRequest {
  RegisterUserRequest({
    required this.username,
    required this.phoneNumber,
    this.email,
    required this.password,
    this.verificationCode,
  });

  final String username;
  final String phoneNumber;
  final String? email;
  final String password;
  final String? verificationCode;

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'phoneNumber': phoneNumber,
      if (email != null && email!.isNotEmpty) 'email': email,
      'password': password,
      if(verificationCode!=null&&verificationCode!.isNotEmpty)'verificationCode':verificationCode,
    };
  }
}

class RegisterUserResult {
  RegisterUserResult({
    required this.id,
    required this.username,
    required this.phoneNumber,
    this.email,
  });

  final int id;
  final String username;
  final String? email;
  final String phoneNumber;

  factory RegisterUserResult.fromJson(Map<String, dynamic> json) {
    return RegisterUserResult(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String? ?? '',
      email: json['email'] as String?,
      phoneNumber: json['phoneNumber'] as String? ?? '',
    );
  }
}
