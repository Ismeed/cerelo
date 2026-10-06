import 'package:cerelo_core/cerelo_core.dart';

/// DTO for a Customer's own profile data.
///
/// Returned by `get_current_customer` and onboarding RPCs.
class CustomerProfileDto {
  const CustomerProfileDto({
    required this.id,
    required this.fullName,
    required this.accountType,
    this.email,
    this.phoneNumber,
    this.businessName,
    this.isActive = true,
    this.onboardingCompletedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? email;
  final String fullName;
  final String? phoneNumber;
  final AccountType accountType;
  final String? businessName;
  final bool isActive;
  final DateTime? onboardingCompletedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Authoritative check: whether customer has finished onboarding.
  bool get isOnboardingComplete => onboardingCompletedAt != null;

  /// Whether this customer has classified their account as a business.
  bool get isBusiness => accountType == AccountType.business;

  factory CustomerProfileDto.fromJson(Map<String, dynamic> json) {
    final accountTypeRaw = json['account_type'] as String? ?? 'INDIVIDUAL';
    final accountType = AccountType.fromString(accountTypeRaw.toLowerCase());

    return CustomerProfileDto(
      id: json['id'] as String,
      email: json['email'] as String?,
      fullName: (json['full_name'] as String?)?.trim() ?? '',
      phoneNumber: json['phone_number'] as String?,
      accountType: accountType,
      businessName: json['business_name'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      onboardingCompletedAt: json['onboarding_completed_at'] != null
          ? DateTime.tryParse(json['onboarding_completed_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'account_type': accountType.name.toUpperCase(),
      'business_name': businessName,
      'is_active': isActive,
      'onboarding_completed_at': onboardingCompletedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  CustomerProfileDto copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phoneNumber,
    AccountType? accountType,
    String? businessName,
    bool? isActive,
    DateTime? onboardingCompletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerProfileDto(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      accountType: accountType ?? this.accountType,
      businessName: businessName ?? this.businessName,
      isActive: isActive ?? this.isActive,
      onboardingCompletedAt:
          onboardingCompletedAt ?? this.onboardingCompletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerProfileDto &&
          other.id == id &&
          other.email == email &&
          other.fullName == fullName &&
          other.accountType == accountType &&
          other.businessName == businessName &&
          other.onboardingCompletedAt == onboardingCompletedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      email.hashCode ^
      fullName.hashCode ^
      accountType.hashCode ^
      businessName.hashCode ^
      onboardingCompletedAt.hashCode;
}
