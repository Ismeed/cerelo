import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/shipments_provider.dart';

/// Screen displayed when opening a secure shared tracking link (/s/:token).
///
/// Provides a privacy-safe restricted view of the shipment and allows
/// authenticated receivers to claim the parcel into their "Parcels Received" list.
class SharedShipmentScreen extends ConsumerStatefulWidget {
  const SharedShipmentScreen({
    super.key,
    required this.token,
  });

  final String token;

  @override
  ConsumerState<SharedShipmentScreen> createState() =>
      _SharedShipmentScreenState();
}

class _SharedShipmentScreenState extends ConsumerState<SharedShipmentScreen> {
  SharedShipmentDto? _sharedShipment;
  bool _isLoading = true;
  bool _isClaiming = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _resolveToken();
  }

  Future<void> _resolveToken() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(shipmentServiceProvider);
      final shipment = await service.resolveShareToken(widget.token);
      if (mounted) {
        setState(() {
          _sharedShipment = shipment;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not resolve shipment link.';
        });
      }
    }
  }

  Future<void> _claimDelivery() async {
    setState(() => _isClaiming = true);

    try {
      final service = ref.read(shipmentServiceProvider);
      final success = await service.linkAuthenticatedReceiver(widget.token);

      if (mounted) {
        setState(() => _isClaiming = false);
        if (success && _sharedShipment != null) {
          // Invalidate shipments query so Parcels Received refreshes
          ref.invalidate(customerShipmentsProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Delivery added to your received parcels!'),
              backgroundColor: CereloColors.success,
            ),
          );
          context.go('/shipments/${_sharedShipment!.shipmentId}');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClaiming = false);
        final message =
            e is CereloApiError ? e.message : 'Could not link delivery.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: CereloColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(customerAuthProvider);
    final isAuthenticated = authState.isAuthenticated;

    return Scaffold(
      backgroundColor: CereloColors.surface,
      appBar: AppBar(
        title: const Text('Shared Delivery'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CereloLoading(message: 'Loading shared delivery...'),
              )
            : _sharedShipment == null
                ? _buildInvalidTokenState()
                : _buildSharedContent(isAuthenticated),
      ),
    );
  }

  Widget _buildSharedContent(bool isAuthenticated) {
    final s = _sharedShipment!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(CereloSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Route Card
          Container(
            padding: const EdgeInsets.all(CereloSpacing.lg),
            decoration: BoxDecoration(
              color: CereloColors.white,
              borderRadius: BorderRadius.circular(CereloSpacing.radiusLg),
              border: Border.all(color: CereloColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          s.originCity,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: CereloColors.navy,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: CereloColors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          s.destinationCity,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: CereloColors.navy,
                          ),
                        ),
                      ],
                    ),
                    CereloStatusBadge(status: s.status),
                  ],
                ),
                const SizedBox(height: CereloSpacing.md),
                Text(
                  'From: ${s.senderDisplayName}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CereloColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'To: ${s.receiverNameSnapshot} (${s.receiverPhoneMasked})',
                  style: const TextStyle(
                    fontSize: 13,
                    color: CereloColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: CereloSpacing.md),

          // Details Card
          Container(
            padding: const EdgeInsets.all(CereloSpacing.md),
            decoration: BoxDecoration(
              color: CereloColors.white,
              borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
              border: Border.all(color: CereloColors.border),
            ),
            child: Column(
              children: [
                _InfoRow(label: 'Contents', value: s.categoryDescription),
                const Divider(),
                _InfoRow(
                  label: 'Delivery Address',
                  value: s.receiverDeliveryAddress.isNotEmpty
                      ? s.receiverDeliveryAddress
                      : '${s.destinationCity} (Doorstep delivery)',
                ),
                const Divider(),
                _InfoRow(
                  label: 'Payment Responsibility',
                  value: s.paymentMode == PaymentMode.senderPays
                      ? 'Paid by Sender'
                      : (s.paymentMode == PaymentMode.receiverPays
                          ? 'You pay ${s.receiverExpectedAmount.formatted} at delivery'
                          : 'Split: You pay ${s.receiverExpectedAmount.formatted} at delivery'),
                  valueStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: s.paymentMode == PaymentMode.senderPays
                        ? CereloColors.success
                        : CereloColors.navy,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: CereloSpacing.xl),

          // Claim / Link Action
          if (!isAuthenticated) ...[
            Container(
              padding: const EdgeInsets.all(CereloSpacing.md),
              decoration: BoxDecoration(
                color: CereloColors.surfaceVariant,
                borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
              ),
              child: const Text(
                'Sign in or create a free Cerelo account to track this parcel under your Received deliveries and receive doorstep delivery updates.',
                style: TextStyle(
                  fontSize: 12,
                  color: CereloColors.textSecondary,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: CereloSpacing.md),
            CereloButton(
              label: 'Sign In to Claim Delivery',
              variant: CereloButtonVariant.primary,
              onPressed: () => context.go(AppRoutes.login),
            ),
          ] else if (s.alreadyLinked) ...[
            CereloButton(
              label: 'View in My Deliveries',
              variant: CereloButtonVariant.primary,
              onPressed: () {
                context.go('/shipments/${s.shipmentId}');
              },
            ),
          ] else ...[
            CereloButton(
              label: 'Add to My Received Deliveries',
              variant: CereloButtonVariant.primary,
              isLoading: _isClaiming,
              leadingIcon: Icons.add_link_rounded,
              onPressed: _claimDelivery,
            ),
          ],

          const SizedBox(height: CereloSpacing.md),
        ],
      ),
    );
  }

  Widget _buildInvalidTokenState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CereloSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.link_off_rounded,
              size: 48,
              color: CereloColors.textTertiary,
            ),
            const SizedBox(height: CereloSpacing.md),
            const Text(
              'Link Unavailable',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: CereloColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'This delivery link is invalid, expired, or has been revoked by the sender.',
              style: TextStyle(
                fontSize: 13,
                color: CereloColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: CereloSpacing.lg),
            CereloButton(
              label: 'Go to Home',
              isFullWidth: false,
              onPressed: () => context.go(AppRoutes.home),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: CereloColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle ??
                  const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CereloColors.textPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
