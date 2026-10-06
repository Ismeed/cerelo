import 'package:supabase_flutter/supabase_flutter.dart';
import '../client/cerelo_supabase_client.dart';

/// Milestone event types for customer and operational notifications.
enum NotificationEventType {
  parcelConfirmed,
  inTransit,
  arrivedDestination,
  outForDelivery,
  delivered,
  actionRequired;

  String toDbCode() {
    switch (this) {
      case NotificationEventType.parcelConfirmed:
        return 'PARCEL_CONFIRMED';
      case NotificationEventType.inTransit:
        return 'IN_TRANSIT';
      case NotificationEventType.arrivedDestination:
        return 'ARRIVED_DESTINATION';
      case NotificationEventType.outForDelivery:
        return 'OUT_FOR_DELIVERY';
      case NotificationEventType.delivered:
        return 'DELIVERED';
      case NotificationEventType.actionRequired:
        return 'ACTION_REQUIRED';
    }
  }

  /// Returns privacy-safe customer notification text. Excludes sensitive PII (addresses, phone numbers).
  String getSafeMessage({String destinationCity = 'destination'}) {
    switch (this) {
      case NotificationEventType.parcelConfirmed:
        return 'Your package has been confirmed by Cerelo.';
      case NotificationEventType.inTransit:
        return 'Your package is now in transit to $destinationCity.';
      case NotificationEventType.arrivedDestination:
        return 'Your package has arrived in $destinationCity.';
      case NotificationEventType.outForDelivery:
        return 'Your package is out for delivery.';
      case NotificationEventType.delivered:
        return 'Your package has been delivered.';
      case NotificationEventType.actionRequired:
        return 'Please review your Cerelo shipment details.';
    }
  }
}

/// Service managing device registration and privacy-safe push notification triggers.
class NotificationService {
  final SupabaseClient _client;

  NotificationService({SupabaseClient? client})
      : _client = client ?? CereloSupabaseClient.instance;

  /// Registers or refreshes the active device token for the authenticated user.
  Future<bool> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    try {
      final response = await _client.rpc<dynamic>(
        'register_device_token',
        params: {
          'p_device_token': token,
          'p_platform': platform.toUpperCase(),
        },
      );
      return response != null;
    } catch (_) {
      return false;
    }
  }

  /// Unregisters an existing device token on logout or permission revocation.
  Future<bool> unregisterDeviceToken(String token) async {
    try {
      final response = await _client.rpc<dynamic>(
        'unregister_device_token',
        params: {'p_device_token': token},
      );
      return response != null;
    } catch (_) {
      return false;
    }
  }
}
