/// Cerelo Core — Shared domain types, enums, validation utilities.
///
/// This package is consumed by customer_app and personnel_app.
///
/// SECURITY: Do not add server authorization logic, service credentials,
/// or privileged database code to this package.
library cerelo_core;

// Domain Enums & Identifiers
export 'src/enums/account_type.dart';
export 'src/enums/actor_role.dart';
export 'src/enums/batch_status.dart';
export 'src/enums/parcel_size.dart';
export 'src/enums/parcel_state.dart';
export 'src/enums/payment_mode.dart';
export 'src/enums/payment_status.dart';
export 'src/enums/shipment_status.dart';
export 'src/errors/cerelo_error_code.dart';
export 'src/identifiers/delivery_code.dart';
export 'src/money/money.dart';
export 'src/phone/phone_number.dart';
export 'src/reliability/operational_incident_category.dart';
