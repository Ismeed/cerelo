/// Canonical operational incident categories across all physical stages in Cerelo V1.
enum OperationalIncidentCategory {
  // Pickup stage
  senderUnavailable,
  addressUnreachable,
  parcelNotReady,
  prohibitedParcel,
  receiverNoAnswer,
  receiverInvalidNumber,
  receiverUnawareOrDisputes,
  correctedPriceRejected,
  senderPaymentRefused,

  // Origin Hub stage
  unreadableOrDamagedQr,
  unidentifiedParcel,
  damagedParcelOrigin,
  labelMismatch,
  wrongOriginHub,

  // Middle-Mile Transit stage
  transportDelayedBeforeDeparture,
  transportCancelledBeforeDeparture,
  transportIssueInTransit,
  manifestDiscrepancy,

  // Destination Reconciliation stage
  expectedParcelMissing,
  unexpectedParcelFound,
  wrongBatchParcel,
  damagedParcelDestination,
  unreadableLabelDestination,

  // Final-Mile Delivery stage
  receiverUnavailable,
  wrongDeliveryAddress,
  receiverRefusedParcel,
  receiverRefusedPayment,
  damagedBeforeHandover,
  failedDeliveryAttempt;

  String toDbCode() {
    switch (this) {
      case OperationalIncidentCategory.senderUnavailable:
        return 'SENDER_UNAVAILABLE';
      case OperationalIncidentCategory.addressUnreachable:
        return 'ADDRESS_UNREACHABLE';
      case OperationalIncidentCategory.parcelNotReady:
        return 'PARCEL_NOT_READY';
      case OperationalIncidentCategory.prohibitedParcel:
        return 'PROHIBITED_PARCEL';
      case OperationalIncidentCategory.receiverNoAnswer:
        return 'RECEIVER_NO_ANSWER';
      case OperationalIncidentCategory.receiverInvalidNumber:
        return 'RECEIVER_INVALID_NUMBER';
      case OperationalIncidentCategory.receiverUnawareOrDisputes:
        return 'RECEIVER_UNAWARE_OR_DISPUTES';
      case OperationalIncidentCategory.correctedPriceRejected:
        return 'CORRECTED_PRICE_REJECTED';
      case OperationalIncidentCategory.senderPaymentRefused:
        return 'SENDER_PAYMENT_REFUSED';

      case OperationalIncidentCategory.unreadableOrDamagedQr:
        return 'UNREADABLE_OR_DAMAGED_QR';
      case OperationalIncidentCategory.unidentifiedParcel:
        return 'UNIDENTIFIED_PARCEL';
      case OperationalIncidentCategory.damagedParcelOrigin:
        return 'DAMAGED_PARCEL_ORIGIN';
      case OperationalIncidentCategory.labelMismatch:
        return 'LABEL_MISMATCH';
      case OperationalIncidentCategory.wrongOriginHub:
        return 'WRONG_ORIGIN_HUB';

      case OperationalIncidentCategory.transportDelayedBeforeDeparture:
        return 'TRANSPORT_DELAYED_BEFORE_DEPARTURE';
      case OperationalIncidentCategory.transportCancelledBeforeDeparture:
        return 'TRANSPORT_CANCELLED_BEFORE_DEPARTURE';
      case OperationalIncidentCategory.transportIssueInTransit:
        return 'TRANSPORT_ISSUE_IN_TRANSIT';
      case OperationalIncidentCategory.manifestDiscrepancy:
        return 'MANIFEST_DISCREPANCY';

      case OperationalIncidentCategory.expectedParcelMissing:
        return 'EXPECTED_PARCEL_MISSING';
      case OperationalIncidentCategory.unexpectedParcelFound:
        return 'UNEXPECTED_PARCEL_FOUND';
      case OperationalIncidentCategory.wrongBatchParcel:
        return 'WRONG_BATCH_PARCEL';
      case OperationalIncidentCategory.damagedParcelDestination:
        return 'DAMAGED_PARCEL_DESTINATION';
      case OperationalIncidentCategory.unreadableLabelDestination:
        return 'UNREADABLE_LABEL_DESTINATION';

      case OperationalIncidentCategory.receiverUnavailable:
        return 'RECEIVER_UNAVAILABLE';
      case OperationalIncidentCategory.wrongDeliveryAddress:
        return 'WRONG_DELIVERY_ADDRESS';
      case OperationalIncidentCategory.receiverRefusedParcel:
        return 'RECEIVER_REFUSED_PARCEL';
      case OperationalIncidentCategory.receiverRefusedPayment:
        return 'RECEIVER_REFUSED_PAYMENT';
      case OperationalIncidentCategory.damagedBeforeHandover:
        return 'DAMAGED_BEFORE_HANDOVER';
      case OperationalIncidentCategory.failedDeliveryAttempt:
        return 'FAILED_DELIVERY_ATTEMPT';
    }
  }

  static OperationalIncidentCategory fromDbCode(String code) {
    switch (code.toUpperCase()) {
      case 'SENDER_UNAVAILABLE':
        return OperationalIncidentCategory.senderUnavailable;
      case 'ADDRESS_UNREACHABLE':
        return OperationalIncidentCategory.addressUnreachable;
      case 'PARCEL_NOT_READY':
        return OperationalIncidentCategory.parcelNotReady;
      case 'PROHIBITED_PARCEL':
        return OperationalIncidentCategory.prohibitedParcel;
      case 'RECEIVER_NO_ANSWER':
        return OperationalIncidentCategory.receiverNoAnswer;
      case 'RECEIVER_INVALID_NUMBER':
        return OperationalIncidentCategory.receiverInvalidNumber;
      case 'RECEIVER_UNAWARE_OR_DISPUTES':
        return OperationalIncidentCategory.receiverUnawareOrDisputes;
      case 'CORRECTED_PRICE_REJECTED':
        return OperationalIncidentCategory.correctedPriceRejected;
      case 'SENDER_PAYMENT_REFUSED':
        return OperationalIncidentCategory.senderPaymentRefused;

      case 'UNREADABLE_OR_DAMAGED_QR':
        return OperationalIncidentCategory.unreadableOrDamagedQr;
      case 'UNIDENTIFIED_PARCEL':
        return OperationalIncidentCategory.unidentifiedParcel;
      case 'DAMAGED_PARCEL_ORIGIN':
        return OperationalIncidentCategory.damagedParcelOrigin;
      case 'LABEL_MISMATCH':
        return OperationalIncidentCategory.labelMismatch;
      case 'WRONG_ORIGIN_HUB':
        return OperationalIncidentCategory.wrongOriginHub;

      case 'TRANSPORT_DELAYED_BEFORE_DEPARTURE':
        return OperationalIncidentCategory.transportDelayedBeforeDeparture;
      case 'TRANSPORT_CANCELLED_BEFORE_DEPARTURE':
        return OperationalIncidentCategory.transportCancelledBeforeDeparture;
      case 'TRANSPORT_ISSUE_IN_TRANSIT':
        return OperationalIncidentCategory.transportIssueInTransit;
      case 'MANIFEST_DISCREPANCY':
        return OperationalIncidentCategory.manifestDiscrepancy;

      case 'EXPECTED_PARCEL_MISSING':
        return OperationalIncidentCategory.expectedParcelMissing;
      case 'UNEXPECTED_PARCEL_FOUND':
        return OperationalIncidentCategory.unexpectedParcelFound;
      case 'WRONG_BATCH_PARCEL':
        return OperationalIncidentCategory.wrongBatchParcel;
      case 'DAMAGED_PARCEL_DESTINATION':
        return OperationalIncidentCategory.damagedParcelDestination;
      case 'UNREADABLE_LABEL_DESTINATION':
        return OperationalIncidentCategory.unreadableLabelDestination;

      case 'RECEIVER_UNAVAILABLE':
        return OperationalIncidentCategory.receiverUnavailable;
      case 'WRONG_DELIVERY_ADDRESS':
        return OperationalIncidentCategory.wrongDeliveryAddress;
      case 'RECEIVER_REFUSED_PARCEL':
        return OperationalIncidentCategory.receiverRefusedParcel;
      case 'RECEIVER_REFUSED_PAYMENT':
        return OperationalIncidentCategory.receiverRefusedPayment;
      case 'DAMAGED_BEFORE_HANDOVER':
        return OperationalIncidentCategory.damagedBeforeHandover;
      case 'FAILED_DELIVERY_ATTEMPT':
      default:
        return OperationalIncidentCategory.failedDeliveryAttempt;
    }
  }

  /// Converts internal operational categories into simple, respectful, customer-safe copy.
  String toCustomerSafeMessage() {
    switch (this) {
      case OperationalIncidentCategory.senderUnavailable:
      case OperationalIncidentCategory.addressUnreachable:
      case OperationalIncidentCategory.parcelNotReady:
        return 'Pickup could not be completed as scheduled. Our team will contact the sender.';
      case OperationalIncidentCategory.prohibitedParcel:
        return 'This item cannot be accepted for intercity transport under Cerelo safety policy.';
      case OperationalIncidentCategory.receiverNoAnswer:
      case OperationalIncidentCategory.receiverInvalidNumber:
      case OperationalIncidentCategory.receiverUnawareOrDisputes:
        return 'We are verifying receiver contact details before dispatching this package.';
      case OperationalIncidentCategory.correctedPriceRejected:
        return 'Pickup cancelled following parcel size verification.';
      case OperationalIncidentCategory.senderPaymentRefused:
        return 'Pickup pending payment arrangement.';

      case OperationalIncidentCategory.unreadableOrDamagedQr:
      case OperationalIncidentCategory.unidentifiedParcel:
      case OperationalIncidentCategory.damagedParcelOrigin:
      case OperationalIncidentCategory.labelMismatch:
      case OperationalIncidentCategory.wrongOriginHub:
        return 'Your package is being securely reviewed at our sorting hub.';

      case OperationalIncidentCategory.transportDelayedBeforeDeparture:
      case OperationalIncidentCategory.transportCancelledBeforeDeparture:
      case OperationalIncidentCategory.transportIssueInTransit:
      case OperationalIncidentCategory.manifestDiscrepancy:
        return 'Middle-mile transport schedule updated. Your package is safely secured.';

      case OperationalIncidentCategory.expectedParcelMissing:
      case OperationalIncidentCategory.unexpectedParcelFound:
      case OperationalIncidentCategory.wrongBatchParcel:
      case OperationalIncidentCategory.damagedParcelDestination:
      case OperationalIncidentCategory.unreadableLabelDestination:
        return 'Destination arrival processing in progress.';

      case OperationalIncidentCategory.receiverUnavailable:
      case OperationalIncidentCategory.wrongDeliveryAddress:
        return 'Delivery attempt was rescheduled. Recipient will be contacted.';
      case OperationalIncidentCategory.receiverRefusedParcel:
      case OperationalIncidentCategory.receiverRefusedPayment:
        return 'Delivery could not be completed. Cerelo operations is reviewing the delivery.';
      case OperationalIncidentCategory.damagedBeforeHandover:
      case OperationalIncidentCategory.failedDeliveryAttempt:
        return 'Delivery attempt temporarily paused for operational review.';
    }
  }
}
