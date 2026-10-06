/// Internal physical parcel custody state.
///
/// These are server-side states — not all are exposed to customers.
/// Customer-facing views receive a mapped ShipmentStatus instead.
enum ParcelState {
  /// Shipment requested; parcel not yet physically collected.
  unconfirmed,

  /// Personnel has physically collected the parcel.
  inCereloCustody,

  /// Parcel staged and sorted at origin hub.
  originHubStaged,

  /// Parcel locked into a confirmed batch manifest.
  batchLocked,

  /// Parcel loaded on middle-mile vehicle, en route.
  corridorTransit,

  /// Parcel arrived at destination hub, staged.
  destinationHubStaged,

  /// Parcel assigned to a final-delivery route.
  finalDeliveryStaged,

  /// Parcel physically handed over to receiver.
  handedOver;

  static ParcelState? fromString(String value) {
    final cleaned = value.replaceAll('_', '').toLowerCase();
    return ParcelState.values.where((e) => e.name.toLowerCase() == cleaned).firstOrNull;
  }
}
