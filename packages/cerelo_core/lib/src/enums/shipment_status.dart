/// Customer-facing shipment status milestones.
///
/// These map to the 7 customer-visible states defined in
/// CERELO_USER_JOURNEYS_AND_STATE_MACHINE.md.
///
/// Internal operational sub-states (e.g., BATCHED, PICKUP_IN_PROGRESS)
/// exist on the server but are mapped to these customer-safe milestones
/// before exposure to the Customer app.
enum ShipmentStatus {
  /// Request created, awaiting Personnel pickup.
  requested,

  /// Personnel has physically collected and confirmed the parcel.
  parcelConfirmed,

  /// Parcel staged at the origin sorting hub.
  atOriginHub,

  /// Parcel loaded into a batch and en route to destination.
  inTransit,

  /// Batch has arrived at the destination hub.
  arrivedDestination,

  /// Personnel is delivering to receiver doorstep.
  outForDelivery,

  /// Parcel successfully handed to receiver.
  delivered,

  /// Delivery could not be completed.
  deliveryFailed,

  /// Shipment request was cancelled (only before pickup).
  cancelled;

  /// Human-readable display label.
  String get displayLabel {
    switch (this) {
      case ShipmentStatus.requested:
        return 'Requested';
      case ShipmentStatus.parcelConfirmed:
        return 'Parcel Confirmed';
      case ShipmentStatus.atOriginHub:
        return 'At Origin Hub';
      case ShipmentStatus.inTransit:
        return 'In Transit';
      case ShipmentStatus.arrivedDestination:
        return 'Arrived Destination';
      case ShipmentStatus.outForDelivery:
        return 'Out for Delivery';
      case ShipmentStatus.delivered:
        return 'Delivered';
      case ShipmentStatus.deliveryFailed:
        return 'Delivery Failed';
      case ShipmentStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Whether this shipment is still in active transit.
  bool get isActive =>
      this != ShipmentStatus.delivered &&
      this != ShipmentStatus.deliveryFailed &&
      this != ShipmentStatus.cancelled;

  static ShipmentStatus? fromString(String value) {
    final cleaned = value.replaceAll('_', '').toLowerCase();
    return ShipmentStatus.values.where((e) => e.name.toLowerCase() == cleaned).firstOrNull;
  }
}
