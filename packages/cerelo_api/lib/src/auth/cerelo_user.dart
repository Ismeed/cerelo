import 'package:cerelo_core/cerelo_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents the currently authenticated Cerelo user with their resolved role.
///
/// SECURITY: Role is derived from server-issued JWT claims (app_metadata.role),
/// never from client-provided values. Never trust a role stored locally if it
/// contradicts the server-issued JWT.
class CereloUser {
  const CereloUser({
    required this.id,
    required this.email,
    required this.role,
    required this.phoneNumber,
    this.fullName,
  });

  /// Internal Supabase user UUID.
  final String id;

  /// User's email address.
  final String? email;

  /// Server-issued role from JWT app_metadata.
  /// This determines which application surfaces the user may access.
  final ActorRole role;

  /// Verified phone number (E.164 format), if present.
  final String? phoneNumber;

  /// Full name from user metadata (e.g. Google profile or signup metadata), if present.
  final String? fullName;

  /// Constructs a CereloUser from the Supabase Auth User object.
  ///
  /// The role is extracted from app_metadata (server-set), not user_metadata
  /// (client-settable) to prevent privilege escalation.
  factory CereloUser.fromSupabaseUser(User user) {
    // SECURITY: Role comes from app_metadata (server-controlled JWT claim),
    // NOT from user_metadata which clients can modify.
    final roleString = user.appMetadata['role'] as String?;
    final role = ActorRole.fromString(roleString ?? '') ?? ActorRole.customer;
    final fullName = (user.userMetadata?['full_name'] ??
        user.userMetadata?['name']) as String?;

    return CereloUser(
      id: user.id,
      email: user.email,
      role: role,
      phoneNumber: user.phone,
      fullName: fullName,
    );
  }

  bool get isCustomer => role == ActorRole.customer;
  bool get isPersonnel => role == ActorRole.personnel;
  bool get isAdmin => role == ActorRole.admin;
}
