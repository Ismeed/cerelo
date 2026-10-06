import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../scanner/screens/personnel_scanner_screen.dart';
import '../providers/hub_provider.dart';
import '../widgets/parcel_label_sheet.dart';

/// Screen listing parcels staged at the origin hub ready for Batch consolidation,
/// with immediate access to QR scanner and label reprinting.
class ParcelsScreen extends ConsumerWidget {
  const ParcelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readyAsync = ref.watch(readyForBatchParcelsProvider);

    return Scaffold(
      backgroundColor: CereloColors.surface,
      appBar: AppBar(
        title: const Text('Parcels in Custody'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan Parcel QR',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PersonnelScannerScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(readyForBatchParcelsProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: CereloColors.orange,
          onRefresh: () async {
            ref.invalidate(readyForBatchParcelsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(CereloSpacing.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Quick Hub Action Card: Scan to Receive at Hub
                Container(
                  padding: const EdgeInsets.all(CereloSpacing.md),
                  decoration: BoxDecoration(
                    color: CereloColors.navy,
                    borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: CereloSpacing.md),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Receive Inbound Parcel',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Scan Parcel QR or enter Delivery Code to stage at hub.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PersonnelScannerScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CereloColors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('Scan'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: CereloSpacing.lg),

                // Section: Ready for Batch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ready for Batch Consolidation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: CereloColors.navy,
                      ),
                    ),
                    readyAsync.maybeWhen(
                      data: (list) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: CereloColors.success.withOpacity(0.12),
                          borderRadius:
                              BorderRadius.circular(CereloSpacing.radiusSm),
                        ),
                        child: Text(
                          '${list.length} READY',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: CereloColors.success,
                          ),
                        ),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Parcels physically received at this origin hub ready to be consolidated into middle-mile batches in Prompt 14.',
                  style: TextStyle(
                    fontSize: 12,
                    color: CereloColors.textSecondary,
                  ),
                ),
                const SizedBox(height: CereloSpacing.md),

                readyAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(CereloSpacing.xl),
                      child: CereloLoading(message: 'Loading staged parcels...'),
                    ),
                  ),
                  error: (_, __) => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(CereloSpacing.md),
                      child: Text(
                        'Could not load staged parcels. Please check your connection.',
                        style: TextStyle(fontSize: 13, color: CereloColors.textSecondary),
                      ),
                    ),
                  ),
                  data: (parcels) {
                    if (parcels.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(CereloSpacing.xl),
                          child: CereloEmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: 'No staged parcels',
                            description:
                                'Scan and receive inbound parcels to prepare them for batch manifest creation.',
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: parcels.length,
                      itemBuilder: (context, index) {
                        final p = parcels[index];
                        return _ReadyForBatchCard(parcel: p);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadyForBatchCard extends StatelessWidget {
  const _ReadyForBatchCard({required this.parcel});

  final ReadyForBatchParcelDto parcel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: CereloSpacing.sm),
      decoration: BoxDecoration(
        color: CereloColors.white,
        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
        border: Border.all(color: CereloColors.border),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: CereloColors.surfaceVariant,
            borderRadius: BorderRadius.circular(CereloSpacing.radiusSm),
          ),
          child: const Icon(
            Icons.inventory_2_rounded,
            color: CereloColors.navy,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Text(
              parcel.routeDisplay,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: CereloColors.navy,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: CereloColors.navy.withOpacity(0.08),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                parcel.confirmedSizeName,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: CereloColors.navy,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Code: ${parcel.deliveryCode} • ${parcel.categoryDescription}',
              style: const TextStyle(fontSize: 12, color: CereloColors.textSecondary),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.print_outlined, size: 20),
          tooltip: 'Reprint Label',
          onPressed: () {
            final resolved = ResolvedParcelDto(
              parcelId: parcel.parcelId,
              shipmentId: parcel.shipmentId,
              deliveryCode: parcel.deliveryCode,
              parcelQrToken: parcel.parcelQrToken,
              currentParcelState: ParcelState.originHubStaged,
              currentStatus: ShipmentStatus.atOriginHub,
              originCity: parcel.originCity,
              destinationCity: parcel.destinationCity,
              senderName: 'Sender',
              receiverName: 'Receiver',
              confirmedSizeCode: parcel.confirmedSizeCode,
              confirmedSizeName: parcel.confirmedSizeName,
              categoryDescription: parcel.categoryDescription,
              finalPrice: Money.fromNaira(3500),
              paymentMode: PaymentMode.senderPays,
              isHubReceived: true,
              isReadyForBatch: true,
            );
            ParcelLabelSheet.show(context, resolved);
          },
        ),
      ),
    );
  }
}
