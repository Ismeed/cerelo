/// Cerelo API — Shared Supabase client, DTOs, and data-access helpers.
///
/// SECURITY:
/// - Never put Supabase service role keys or privileged credentials in this package.
/// - This package uses only the public anon key for authenticated client calls.
/// - All sensitive mutations must go through Edge Function RPCs, never direct table updates.
library cerelo_api;

// Core domain re-export
export 'package:cerelo_core/cerelo_core.dart';

// Auth
export 'src/auth/auth_service.dart';
export 'src/auth/cerelo_user.dart';

// Supabase client
export 'src/client/cerelo_supabase_client.dart';

// Customer Domain
export 'src/customer/customer_service.dart';

// DTOs
export 'src/dto/batch_dto.dart';
export 'src/dto/customer_profile_dto.dart';
export 'src/dto/delivery_quote_dto.dart';
export 'src/dto/delivery_task_dto.dart';
export 'src/dto/personnel_profile_dto.dart';
export 'src/dto/pickup_task_dto.dart';
export 'src/dto/resolved_parcel_dto.dart';
export 'src/dto/shared_shipment_dto.dart';
export 'src/dto/shipment_dto.dart';

// Errors
export 'src/errors/api_error.dart';

// Notifications & Reliability
export 'src/notifications/notification_service.dart';
export 'src/reliability/retry_policy.dart';

// Personnel Domain
export 'src/personnel/personnel_batch_service.dart';
export 'src/personnel/personnel_delivery_service.dart';
export 'src/personnel/personnel_hub_service.dart';
export 'src/personnel/personnel_pickup_service.dart';

// Shipment Domain
export 'src/shipment/shipment_service.dart';
