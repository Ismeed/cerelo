/// Actor roles within the Cerelo V1 system.
///
/// These roles are used for authorization decisions on both client (UX)
/// and server (authoritative enforcement).
///
/// SECURITY: Never grant permissions based solely on client-reported role.
/// Always verify role from server-issued JWT claims.
enum ActorRole {
  /// Normal Cerelo user (Sender or Receiver on a per-shipment basis).
  customer,

  /// Authorized Cerelo field operational staff.
  personnel,

  /// Internal Cerelo administrative user.
  admin,

  /// System-generated automated actions (e.g., batch notification triggers).
  system;

  static ActorRole? fromString(String value) {
    final cleaned = value.replaceAll('_', '').toLowerCase();
    return ActorRole.values.where((e) => e.name.toLowerCase() == cleaned).firstOrNull;
  }
}
