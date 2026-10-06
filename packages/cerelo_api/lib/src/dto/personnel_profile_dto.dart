/// DTO representing the authoritative profile and authorization state of a Personnel user.
class PersonnelProfileDto {
  const PersonnelProfileDto({
    required this.isAuthorized,
    this.reason,
    this.personnelId,
    this.userId,
    this.fullName,
    this.phoneNumber,
    this.employeeReference,
    this.operatingHubId,
    this.hubCode,
    this.hubName,
    this.cityId,
    this.cityName,
    this.email,
    this.isActive = false,
  });

  final bool isAuthorized;
  final String? reason;
  final String? personnelId;
  final String? userId;
  final String? fullName;
  final String? phoneNumber;
  final String? employeeReference;
  final String? operatingHubId;
  final String? hubCode;
  final String? hubName;
  final String? cityId;
  final String? cityName;
  final String? email;
  final bool isActive;

  String get hubDisplay => hubName != null && hubCode != null
      ? '$hubName ($hubCode)'
      : operatingHubId ?? 'No Hub Assigned';

  factory PersonnelProfileDto.fromJson(Map<String, dynamic> json) {
    return PersonnelProfileDto(
      isAuthorized: json['is_authorized'] as bool? ?? false,
      reason: json['reason'] as String?,
      personnelId: json['personnel_id'] as String?,
      userId: json['user_id'] as String?,
      fullName: json['full_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      employeeReference: json['employee_reference'] as String?,
      operatingHubId: json['operating_hub_id'] as String?,
      hubCode: json['hub_code'] as String?,
      hubName: json['hub_name'] as String?,
      cityId: json['city_id'] as String?,
      cityName: json['city_name'] as String?,
      email: json['email'] as String?,
      isActive: json['is_active'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_authorized': isAuthorized,
      'reason': reason,
      'personnel_id': personnelId,
      'user_id': userId,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'employee_reference': employeeReference,
      'operating_hub_id': operatingHubId,
      'hub_code': hubCode,
      'hub_name': hubName,
      'city_id': cityId,
      'city_name': cityName,
      'email': email,
      'is_active': isActive,
    };
  }

  factory PersonnelProfileDto.unauthorized([String reason = 'UNAUTHORIZED']) {
    return PersonnelProfileDto(
      isAuthorized: false,
      reason: reason,
    );
  }
}
