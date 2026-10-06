import 'package:cerelo_core/cerelo_core.dart';

/// DTO for a server-authoritative delivery price quote.
class DeliveryQuoteDto {
  const DeliveryQuoteDto({
    required this.corridorId,
    required this.sizeTierId,
    required this.sizeTierCode,
    required this.sizeTierName,
    required this.sizeTierDescription,
    required this.quotedPrice,
    this.currency = 'NGN',
  });

  final String corridorId;
  final String sizeTierId;
  final String sizeTierCode;
  final String sizeTierName;
  final String sizeTierDescription;
  final Money quotedPrice;
  final String currency;

  factory DeliveryQuoteDto.fromJson(Map<String, dynamic> json) {
    final kobo = (json['quoted_price_amount'] as num?)?.toInt() ?? 0;
    return DeliveryQuoteDto(
      corridorId: json['corridor_id'] as String? ?? '',
      sizeTierId: json['size_tier_id'] as String? ?? '',
      sizeTierCode: json['size_tier_code'] as String? ?? 'MEDIUM',
      sizeTierName: json['size_tier_name'] as String? ?? 'Medium Package',
      sizeTierDescription: json['size_tier_description'] as String? ?? '',
      quotedPrice: Money.fromKobo(kobo),
      currency: json['currency'] as String? ?? 'NGN',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'corridor_id': corridorId,
      'size_tier_id': sizeTierId,
      'size_tier_code': sizeTierCode,
      'size_tier_name': sizeTierName,
      'size_tier_description': sizeTierDescription,
      'quoted_price_amount': quotedPrice.kobo,
      'currency': currency,
    };
  }
}

/// DTO for a parcel size tier configuration item.
class ParcelSizeTierDto {
  const ParcelSizeTierDto({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.maxWeightKg,
    required this.displayOrder,
  });

  final String id;
  final ParcelSize code;
  final String name;
  final String description;
  final double maxWeightKg;
  final int displayOrder;

  factory ParcelSizeTierDto.fromJson(Map<String, dynamic> json) {
    final codeStr = json['code'] as String? ?? 'MEDIUM';
    final size = ParcelSize.fromString(codeStr.toLowerCase()) ?? ParcelSize.medium;

    return ParcelSizeTierDto(
      id: json['id'] as String? ?? '',
      code: size,
      name: json['name'] as String? ?? size.displayLabel,
      description: json['description'] as String? ?? '',
      maxWeightKg: (json['max_weight_kg'] as num?)?.toDouble() ?? 5.0,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
    );
  }
}
