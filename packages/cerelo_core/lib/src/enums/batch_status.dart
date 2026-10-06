/// Lifecycle status of a Cerelo Batch container.
enum BatchStatus {
  /// Batch created, parcels being added.
  draft,

  /// Manifest locked and confirmed by Personnel.
  confirmed,

  /// Batch loaded onto middle-mile vehicle and departed origin.
  onboarded,

  /// Batch arrived at destination hub, pending reconciliation.
  destinationReceived,

  /// Reconciliation in progress.
  reconciling,

  /// All parcels accounted for.
  reconciled,

  /// Batch operationally closed.
  closed,

  /// Draft batch cancelled and discarded.
  cancelled;

  bool get isActive =>
      this != BatchStatus.reconciled &&
      this != BatchStatus.closed &&
      this != BatchStatus.cancelled;

  static BatchStatus? fromString(String value) {
    final cleaned = value.replaceAll('_', '').toLowerCase();
    return BatchStatus.values.where((e) => e.name.toLowerCase() == cleaned).firstOrNull;
  }
}
