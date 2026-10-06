import 'package:cerelo_core/cerelo_core.dart';
import 'resolved_parcel_dto.dart';

/// Summary DTO for a Batch in the Personnel operations list.
class BatchSummaryDto {
  const BatchSummaryDto({
    required this.id,
    this.batchReference,
    this.batchQrToken,
    required this.status,
    required this.corridorCode,
    required this.originCity,
    required this.destinationCity,
    this.originHubId,
    this.originHubCode,
    this.destinationHubId,
    this.destinationHubCode,
    required this.manifestParcelCount,
    this.driverName,
    this.driverPhone,
    this.vehiclePlateNumber,
    this.actualDepartureAt,
    this.confirmedAt,
    this.onboardedAt,
    required this.createdAt,
  });

  final String id;
  final String? batchReference;
  final String? batchQrToken;
  final BatchStatus status;
  final String corridorCode;
  final String originCity;
  final String destinationCity;
  final String? originHubId;
  final String? originHubCode;
  final String? destinationHubId;
  final String? destinationHubCode;
  final int manifestParcelCount;
  final String? driverName;
  final String? driverPhone;
  final String? vehiclePlateNumber;
  final DateTime? actualDepartureAt;
  final DateTime? confirmedAt;
  final DateTime? onboardedAt;
  final DateTime createdAt;

  String get routeDisplay => '$originCity → $destinationCity';

  factory BatchSummaryDto.fromJson(Map<String, dynamic> json) {
    final statusStr = json['current_batch_state'] as String? ?? 'DRAFT';
    final status = BatchStatus.fromString(statusStr.toLowerCase()) ??
        BatchStatus.draft;

    return BatchSummaryDto(
      id: json['id'] as String? ?? '',
      batchReference: json['batch_reference'] as String?,
      batchQrToken: json['batch_qr_token'] as String?,
      status: status,
      corridorCode: json['corridor_code'] as String? ?? 'KAN-KAT',
      originCity: json['origin_city'] as String? ?? 'Kano',
      destinationCity: json['destination_city'] as String? ?? 'Katsina',
      originHubId: json['origin_hub_id'] as String?,
      originHubCode: json['origin_hub_code'] as String?,
      destinationHubId: json['destination_hub_id'] as String?,
      destinationHubCode: json['destination_hub_code'] as String?,
      manifestParcelCount: (json['manifest_parcel_count'] as num?)?.toInt() ?? 0,
      driverName: json['driver_name'] as String?,
      driverPhone: json['driver_phone'] as String?,
      vehiclePlateNumber: json['vehicle_plate_number'] as String?,
      actualDepartureAt: json['actual_departure_at'] != null
          ? DateTime.parse(json['actual_departure_at'] as String)
          : null,
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.parse(json['confirmed_at'] as String)
          : null,
      onboardedAt: json['onboarded_at'] != null
          ? DateTime.parse(json['onboarded_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'batch_reference': batchReference,
      'batch_qr_token': batchQrToken,
      'current_batch_state': status.name.toUpperCase(),
      'corridor_code': corridorCode,
      'origin_city': originCity,
      'destination_city': destinationCity,
      'origin_hub_id': originHubId,
      'origin_hub_code': originHubCode,
      'destination_hub_id': destinationHubId,
      'destination_hub_code': destinationHubCode,
      'manifest_parcel_count': manifestParcelCount,
      'driver_name': driverName,
      'driver_phone': driverPhone,
      'vehicle_plate_number': vehiclePlateNumber,
      'actual_departure_at': actualDepartureAt?.toIso8601String(),
      'confirmed_at': confirmedAt?.toIso8601String(),
      'onboarded_at': onboardedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Full manifest DTO for an operational Batch.
class BatchManifestDto {
  const BatchManifestDto({
    required this.batchId,
    required this.batchReference,
    this.batchQrToken,
    required this.status,
    required this.corridorCode,
    required this.originCity,
    required this.destinationCity,
    required this.manifestParcelCount,
    this.driverName,
    this.driverPhone,
    this.vehiclePlateNumber,
    required this.agreedCost,
    this.confirmedAt,
    this.onboardedAt,
    required this.parcels,
  });

  final String batchId;
  final String batchReference;
  final String? batchQrToken;
  final BatchStatus status;
  final String corridorCode;
  final String originCity;
  final String destinationCity;
  final int manifestParcelCount;
  final String? driverName;
  final String? driverPhone;
  final String? vehiclePlateNumber;
  final Money agreedCost;
  final DateTime? confirmedAt;
  final DateTime? onboardedAt;
  final List<ReadyForBatchParcelDto> parcels;

  String get routeDisplay => '$originCity → $destinationCity';

  factory BatchManifestDto.fromJson(Map<String, dynamic> json) {
    final statusStr = json['current_batch_state'] as String? ?? 'DRAFT';
    final status = BatchStatus.fromString(statusStr.toLowerCase()) ??
        BatchStatus.draft;

    final costKobo = (json['agreed_cost_amount'] as num?)?.toInt() ?? 0;

    final parcelsRaw = json['parcels'] as List? ?? [];
    final parcels = parcelsRaw
        .map((p) =>
            ReadyForBatchParcelDto.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();

    return BatchManifestDto(
      batchId: json['batch_id'] as String? ?? '',
      batchReference: json['batch_reference'] as String? ?? 'BAT-0000-0000',
      batchQrToken: json['batch_qr_token'] as String?,
      status: status,
      corridorCode: json['corridor_code'] as String? ?? 'KAN-KAT',
      originCity: json['origin_city'] as String? ?? 'Kano',
      destinationCity: json['destination_city'] as String? ?? 'Katsina',
      manifestParcelCount:
          (json['manifest_parcel_count'] as num?)?.toInt() ?? parcels.length,
      driverName: json['driver_name'] as String?,
      driverPhone: json['driver_phone'] as String?,
      vehiclePlateNumber: json['vehicle_plate_number'] as String?,
      agreedCost: Money.fromKobo(costKobo),
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.parse(json['confirmed_at'] as String)
          : null,
      onboardedAt: json['onboarded_at'] != null
          ? DateTime.parse(json['onboarded_at'] as String)
          : null,
      parcels: parcels,
    );
  }
}
