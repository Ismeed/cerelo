import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../providers/send_package_provider.dart';

/// Multi-step "Send a Package" intercity delivery request wizard.
///
/// Steps:
/// 0: Route & Pickup
/// 1: Receiver Details
/// 2: Parcel Details & Size
/// 3: Payment Responsibility
/// 4: Review & Request
class SendPackageScreen extends ConsumerStatefulWidget {
  const SendPackageScreen({super.key});

  @override
  ConsumerState<SendPackageScreen> createState() => _SendPackageScreenState();
}

class _SendPackageScreenState extends ConsumerState<SendPackageScreen> {
  int _currentStep = 0;

  // Step 1 Controllers
  late final TextEditingController _pickupAddressController;
  late final TextEditingController _landmarkController;
  late final TextEditingController _pickupInstructionsController;

  // Step 2 Controllers
  late final TextEditingController _receiverNameController;
  late final TextEditingController _receiverPhoneController;
  late final TextEditingController _receiverAddressController;
  late final TextEditingController _deliveryInstructionsController;

  // Step 3 Controllers
  late final TextEditingController _parcelDescController;

  // Step 4 Controllers
  late final TextEditingController _splitAmountController;

  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final draft = ref.read(sendPackageProvider);

    _pickupAddressController =
        TextEditingController(text: draft.senderPickupAddress);
    _landmarkController = TextEditingController(text: draft.landmark);
    _pickupInstructionsController =
        TextEditingController(text: draft.pickupInstructions);

    _receiverNameController =
        TextEditingController(text: draft.receiverName);
    _receiverPhoneController =
        TextEditingController(text: draft.receiverPhone);
    _receiverAddressController =
        TextEditingController(text: draft.receiverDeliveryAddress);
    _deliveryInstructionsController =
        TextEditingController(text: draft.deliveryInstructions);

    _parcelDescController =
        TextEditingController(text: draft.categoryDescription);
    _splitAmountController = TextEditingController(
      text: draft.senderPaymentAmount?.kobo != null
          ? (draft.senderPaymentAmount!.kobo ~/ 100).toString()
          : '',
    );
  }

  @override
  void dispose() {
    _pickupAddressController.dispose();
    _landmarkController.dispose();
    _pickupInstructionsController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    _receiverAddressController.dispose();
    _deliveryInstructionsController.dispose();
    _parcelDescController.dispose();
    _splitAmountController.dispose();
    super.dispose();
  }

  void _onBackPressed() {
    if (_currentStep > 0) {
      // Move one step back within the wizard.
      setState(() => _currentStep--);
    } else {
      // At step 0 — exit the wizard entirely.
      // Use GoRouter-aware pop so we never get trapped when the screen was
      // pushed via context.push(). If there is no back-stack entry we go()
      // directly to Home to guarantee the user escapes the wizard.
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.home);
      }
    }
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(sendPackageProvider);
    final notifier = ref.read(sendPackageProvider.notifier);

    final stepTitles = [
      'Route & Pickup',
      'Receiver Details',
      'Parcel & Size',
      'Payment Responsibility',
      'Review & Request',
    ];


    // PopScope intercepts the Android system Back gesture and hardware back key
    // so they behave identically to the AppBar back button.  canPop:false
    // prevents the platform from handling the pop itself; instead we call
    // _onBackPressed() which either steps back within the wizard or exits to
    // Home via GoRouter.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBackPressed();
      },
      child: Scaffold(
      backgroundColor: CereloColors.surface,
      appBar: AppBar(
        title: Text(stepTitles[_currentStep]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _onBackPressed,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator (5 Steps)
            Container(
              color: CereloColors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: CereloSpacing.pagePadding,
                vertical: CereloSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step ${_currentStep + 1} of 5',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: CereloColors.textSecondary,
                        ),
                      ),
                      Text(
                        stepTitles[_currentStep],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: CereloColors.navy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: (_currentStep + 1) / 5.0,
                    backgroundColor: CereloColors.surfaceVariant,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(CereloColors.orange),
                    minHeight: 4,
                    borderRadius:
                        BorderRadius.circular(CereloSpacing.radiusFull),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Error banner if any
            if (draft.errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(CereloSpacing.md),
                color: CereloColors.errorLight,
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: CereloColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: CereloSpacing.sm),
                    Expanded(
                      child: Text(
                        draft.errorMessage!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: CereloColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Step Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(CereloSpacing.pagePadding),
                child: _buildStepContent(draft, notifier),
              ),
            ),
          ],
        ),
      ),
      ), // PopScope
    );
  }

  Widget _buildStepContent(
    SendPackageDraft draft,
    SendPackageNotifier notifier,
  ) {
    switch (_currentStep) {
      case 0:
        return _buildStep1RoutePickup(draft, notifier);
      case 1:
        return _buildStep2Receiver(draft, notifier);
      case 2:
        return _buildStep3Parcel(draft, notifier);
      case 3:
        return _buildStep4Payment(draft, notifier);
      case 4:
        return _buildStep5Review(draft, notifier);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── STEP 1: ROUTE & PICKUP ────────────────────────────────────────────────
  Widget _buildStep1RoutePickup(
    SendPackageDraft draft,
    SendPackageNotifier notifier,
  ) {
    final isKanoToKatsina = draft.originCity == 'Kano';

    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Direction Selector Card
          Container(
            padding: const EdgeInsets.all(CereloSpacing.md),
            decoration: BoxDecoration(
              color: CereloColors.white,
              borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
              border: Border.all(color: CereloColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Intercity Corridor',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: CereloColors.textSecondary,
                  ),
                ),
                const SizedBox(height: CereloSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(CereloSpacing.sm),
                        decoration: BoxDecoration(
                          color: CereloColors.surfaceVariant,
                          borderRadius:
                              BorderRadius.circular(CereloSpacing.radiusSm),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Origin (Pickup)',
                              style: TextStyle(
                                fontSize: 11,
                                color: CereloColors.textTertiary,
                              ),
                            ),
                            Text(
                              draft.originCity,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: CereloColors.navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.swap_horiz_rounded,
                        color: CereloColors.orange,
                        size: 28,
                      ),
                      tooltip: 'Switch Direction',
                      onPressed: () {
                        notifier.switchCorridorDirection();
                      },
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(CereloSpacing.sm),
                        decoration: BoxDecoration(
                          color: CereloColors.surfaceVariant,
                          borderRadius:
                              BorderRadius.circular(CereloSpacing.radiusSm),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Destination (Dropoff)',
                              style: TextStyle(
                                fontSize: 11,
                                color: CereloColors.textTertiary,
                              ),
                            ),
                            Text(
                              draft.destinationCity,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: CereloColors.navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: CereloSpacing.xs),
                Text(
                  isKanoToKatsina
                      ? 'Kano Hub → Katsina Hub (Door-to-door)'
                      : 'Katsina Hub → Kano Hub (Door-to-door)',
                  style: const TextStyle(
                    fontSize: 11,
                    color: CereloColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: CereloSpacing.lg),

          Text(
            'Pickup Address in ${draft.originCity}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: CereloColors.navy,
            ),
          ),
          const SizedBox(height: CereloSpacing.sm),

          CereloTextField(
            label: 'Street Address / Shop / Plaza',
            hintText: 'e.g. Shop 14, Kwari Market, Fagge',
            controller: _pickupAddressController,
            validator: (val) {
              if (val == null || val.trim().length < 5) {
                return 'Please enter a complete pickup address (min 5 chars).';
              }
              return null;
            },
          ),

          const SizedBox(height: CereloSpacing.md),

          CereloTextField(
            label: 'Landmark (Optional)',
            hintText: 'e.g. Opposite Central Mosque / Near Main Gate',
            controller: _landmarkController,
          ),

          const SizedBox(height: CereloSpacing.md),

          CereloTextField(
            label: 'Pickup Instructions (Optional)',
            hintText: 'e.g. Call before arrival',
            controller: _pickupInstructionsController,
          ),

          const SizedBox(height: CereloSpacing.xl),

          CereloButton(
            label: 'Continue to Receiver Details',
            onPressed: () {
              if (!_step1FormKey.currentState!.validate()) return;
              notifier.setPickupDetails(
                address: _pickupAddressController.text.trim(),
                landmark: _landmarkController.text.trim(),
                instructions: _pickupInstructionsController.text.trim(),
              );
              setState(() => _currentStep = 1);
            },
          ),
        ],
      ),
    );
  }

  // ─── STEP 2: RECEIVER DETAILS ──────────────────────────────────────────────
  Widget _buildStep2Receiver(
    SendPackageDraft draft,
    SendPackageNotifier notifier,
  ) {
    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Who will receive this in ${draft.destinationCity}?',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: CereloColors.navy,
            ),
          ),
          const SizedBox(height: CereloSpacing.sm),

          CereloTextField(
            label: 'Receiver Full Name',
            hintText: 'e.g. Fatima Bello',
            controller: _receiverNameController,
            validator: (val) {
              if (val == null || val.trim().length < 2) {
                return 'Please enter the receiver full name.';
              }
              return null;
            },
          ),

          const SizedBox(height: CereloSpacing.md),

          CereloTextField(
            label: 'Receiver Phone Number',
            hintText: 'e.g. 08012345678',
            keyboardType: TextInputType.phone,
            controller: _receiverPhoneController,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter receiver phone number.';
              }
              final parsed = PhoneNumber.tryParse(val.trim());
              if (parsed == null) {
                return 'Please enter a valid Nigerian phone number.';
              }
              return null;
            },
          ),

          const SizedBox(height: CereloSpacing.md),

          CereloTextField(
            label: 'Delivery Address in ${draft.destinationCity}',
            hintText: 'e.g. No. 45 Kofar Kaura Layout, Katsina',
            controller: _receiverAddressController,
            validator: (val) {
              if (val == null || val.trim().length < 5) {
                return 'Please enter a complete delivery address.';
              }
              return null;
            },
          ),

          const SizedBox(height: CereloSpacing.md),

          CereloTextField(
            label: 'Delivery Instructions (Optional)',
            hintText: 'e.g. Leave package with front desk if absent',
            controller: _deliveryInstructionsController,
          ),

          const SizedBox(height: CereloSpacing.xl),

          CereloButton(
            label: 'Continue to Parcel Details',
            onPressed: () {
              if (!_step2FormKey.currentState!.validate()) return;
              notifier.setReceiverDetails(
                name: _receiverNameController.text.trim(),
                phone: _receiverPhoneController.text.trim(),
                address: _receiverAddressController.text.trim(),
                instructions: _deliveryInstructionsController.text.trim(),
              );
              setState(() => _currentStep = 2);
            },
          ),
        ],
      ),
    );
  }

  // ─── STEP 3: PARCEL DETAILS & SIZE ─────────────────────────────────────────
  Widget _buildStep3Parcel(
    SendPackageDraft draft,
    SendPackageNotifier notifier,
  ) {
    final sizes = [
      (
        size: ParcelSize.small,
        title: 'Small Package',
        desc: 'Documents, small electronics, or accessories (up to 3kg)',
        price: '₦2,000',
      ),
      (
        size: ParcelSize.medium,
        title: 'Medium Package',
        desc: 'Clothing bundles, shoes, or spare parts (up to 10kg)',
        price: '₦3,500',
      ),
      (
        size: ParcelSize.large,
        title: 'Large Package',
        desc: 'Textile bales, large electronics, or cartons (up to 25kg)',
        price: '₦6,000',
      ),
    ];

    return Form(
      key: _step3FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CereloTextField(
            label: 'What are you sending?',
            hintText: 'e.g. Ankara fabrics, shoes, documents',
            controller: _parcelDescController,
            validator: (val) {
              if (val == null || val.trim().length < 2) {
                return 'Please enter a description of the parcel contents.';
              }
              return null;
            },
          ),

          const SizedBox(height: CereloSpacing.lg),

          const Text(
            'Estimated Parcel Size',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: CereloColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose the size tier that best fits your package.',
            style: TextStyle(
              fontSize: 12,
              color: CereloColors.textSecondary,
            ),
          ),
          const SizedBox(height: CereloSpacing.md),

          ...sizes.map((s) {
            final isSelected = draft.parcelSize == s.size;
            return Container(
              margin: const EdgeInsets.only(bottom: CereloSpacing.sm),
              decoration: BoxDecoration(
                color: isSelected
                    ? CereloColors.orange.withOpacity(0.04)
                    : CereloColors.white,
                borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                border: Border.all(
                  color: isSelected
                      ? CereloColors.orange
                      : CereloColors.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ListTile(
                onTap: () {
                  notifier.setParcelDetails(
                    description: _parcelDescController.text.trim(),
                    size: s.size,
                  );
                },
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: isSelected
                      ? CereloColors.orange
                      : CereloColors.textTertiary,
                ),
                title: Text(
                  s.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: CereloColors.navy,
                  ),
                ),
                subtitle: Text(
                  s.desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CereloColors.textSecondary,
                  ),
                ),
                trailing: Text(
                  s.price,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: CereloColors.navy,
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: CereloSpacing.md),

          // Notice: Physical Verification
          Container(
            padding: const EdgeInsets.all(CereloSpacing.md),
            decoration: BoxDecoration(
              color: CereloColors.surfaceVariant,
              borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.scale_rounded,
                  color: CereloColors.navy,
                  size: 20,
                ),
                SizedBox(width: CereloSpacing.sm),
                Expanded(
                  child: Text(
                    'Cerelo personnel will physically verify and confirm the parcel size at pickup.',
                    style: TextStyle(
                      fontSize: 12,
                      color: CereloColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: CereloSpacing.xl),

          CereloButton(
            label: 'Continue to Payment Selection',
            onPressed: () {
              if (!_step3FormKey.currentState!.validate()) return;
              notifier.setParcelDetails(
                description: _parcelDescController.text.trim(),
                size: draft.parcelSize,
              );
              setState(() => _currentStep = 3);
            },
          ),
        ],
      ),
    );
  }

  // ─── STEP 4: PAYMENT RESPONSIBILITY ────────────────────────────────────────
  Widget _buildStep4Payment(
    SendPackageDraft draft,
    SendPackageNotifier notifier,
  ) {
    final totalPrice = draft.currentQuote?.quotedPrice ?? Money.fromNaira(3500);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Quoted Total Price Header
        Container(
          padding: const EdgeInsets.all(CereloSpacing.md),
          decoration: BoxDecoration(
            color: CereloColors.navy,
            borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Authoritative Delivery Fee',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              Text(
                totalPrice.formatted,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: CereloSpacing.lg),

        const Text(
          'Who is responsible for payment?',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: CereloColors.navy,
          ),
        ),
        const SizedBox(height: CereloSpacing.md),

        // Option 1: Sender Pays
        _PaymentOptionCard(
          title: 'Sender Pays (100%)',
          subtitle: 'You pay ${totalPrice.formatted} at pickup.',
          isSelected: draft.paymentMode == PaymentMode.senderPays,
          onTap: () {
            notifier.setPaymentDetails(mode: PaymentMode.senderPays);
          },
        ),

        // Option 2: Receiver Pays
        _PaymentOptionCard(
          title: 'Receiver Pays (100%)',
          subtitle: 'Receiver pays ${totalPrice.formatted} at delivery.',
          isSelected: draft.paymentMode == PaymentMode.receiverPays,
          onTap: () {
            notifier.setPaymentDetails(mode: PaymentMode.receiverPays);
          },
        ),

        // Option 3: Split Payment
        _PaymentOptionCard(
          title: 'Split Payment',
          subtitle: 'You pay a portion at pickup, receiver pays the rest at delivery.',
          isSelected: draft.paymentMode == PaymentMode.splitPayment,
          onTap: () {
            final halfKobo = totalPrice.kobo ~/ 2;
            _splitAmountController.text = (halfKobo ~/ 100).toString();
            notifier.setPaymentDetails(
              mode: PaymentMode.splitPayment,
              senderAmount: Money.fromKobo(halfKobo),
            );
          },
        ),

        // Split Amount Customizer
        if (draft.paymentMode == PaymentMode.splitPayment) ...[
          const SizedBox(height: CereloSpacing.md),
          Container(
            padding: const EdgeInsets.all(CereloSpacing.md),
            decoration: BoxDecoration(
              color: CereloColors.white,
              borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
              border: Border.all(color: CereloColors.orange),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your share to pay at pickup (in Naira):',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: CereloColors.navy,
                  ),
                ),
                const SizedBox(height: CereloSpacing.sm),
                TextField(
                  controller: _splitAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixText: '₦ ',
                    hintText: '1500',
                  ),
                  onChanged: (val) {
                    final naira = int.tryParse(val) ?? 0;
                    if (naira > 0 && naira * 100 < totalPrice.kobo) {
                      notifier.setPaymentDetails(
                        mode: PaymentMode.splitPayment,
                        senderAmount: Money.fromNaira(naira),
                      );
                    }
                  },
                ),
                const SizedBox(height: CereloSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'You pay: ${draft.senderPaymentAmount?.formatted ?? "₦0"}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CereloColors.navy,
                      ),
                    ),
                    Text(
                      'Receiver pays: ${draft.senderPaymentAmount != null ? (totalPrice - draft.senderPaymentAmount!).formatted : totalPrice.formatted}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CereloColors.orangeDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: CereloSpacing.md),

        // Notice: Physical Collection
        Container(
          padding: const EdgeInsets.all(CereloSpacing.md),
          decoration: BoxDecoration(
            color: CereloColors.surfaceVariant,
            borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.payments_outlined,
                color: CereloColors.navy,
                size: 20,
              ),
              SizedBox(width: CereloSpacing.sm),
              Expanded(
                child: Text(
                  'Physical cash payment will be collected by Cerelo Personnel.',
                  style: TextStyle(
                    fontSize: 12,
                    color: CereloColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: CereloSpacing.xl),

        CereloButton(
          label: 'Continue to Review Request',
          onPressed: () {
            if (draft.paymentMode == PaymentMode.splitPayment) {
              if (draft.senderPaymentAmount == null ||
                  draft.senderPaymentAmount!.kobo <= 0 ||
                  draft.senderPaymentAmount!.kobo >= totalPrice.kobo) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid split amount.'),
                    backgroundColor: CereloColors.error,
                  ),
                );
                return;
              }
            }
            setState(() => _currentStep = 4);
          },
        ),
      ],
    );
  }

  // ─── STEP 5: REVIEW & REQUEST ──────────────────────────────────────────────
  Widget _buildStep5Review(
    SendPackageDraft draft,
    SendPackageNotifier notifier,
  ) {
    final totalPrice = draft.currentQuote?.quotedPrice ?? Money.fromNaira(3500);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Review Card 1: Route & Addresses
        _ReviewSectionCard(
          title: 'Route & Addresses',
          onEdit: () => _goToStep(0),
          children: [
            _ReviewRow(
              label: 'Corridor',
              value: '${draft.originCity} → ${draft.destinationCity}',
            ),
            const Divider(),
            _ReviewRow(
              label: 'Pickup Address',
              value: draft.senderPickupAddress,
            ),
            if (draft.landmark.isNotEmpty) ...[
              const Divider(),
              _ReviewRow(label: 'Landmark', value: draft.landmark),
            ],
            const Divider(),
            _ReviewRow(
              label: 'Receiver',
              value: '${draft.receiverName} (${draft.receiverPhone})',
            ),
            const Divider(),
            _ReviewRow(
              label: 'Delivery Address',
              value: draft.receiverDeliveryAddress,
            ),
          ],
        ),

        const SizedBox(height: CereloSpacing.md),

        // Review Card 2: Parcel & Size
        _ReviewSectionCard(
          title: 'Parcel Details',
          onEdit: () => _goToStep(2),
          children: [
            _ReviewRow(
              label: 'Contents',
              value: draft.categoryDescription.isNotEmpty
                  ? draft.categoryDescription
                  : 'General Package',
            ),
            const Divider(),
            _ReviewRow(
              label: 'Provisional Size',
              value: draft.parcelSize.displayLabel,
            ),
          ],
        ),

        const SizedBox(height: CereloSpacing.md),

        // Review Card 3: Price & Payment Responsibility
        _ReviewSectionCard(
          title: 'Price & Payment',
          onEdit: () => _goToStep(3),
          children: [
            _ReviewRow(
              label: 'Total Delivery Fee',
              value: totalPrice.formatted,
              valueStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: CereloColors.navy,
              ),
            ),
            const Divider(),
            _ReviewRow(
              label: 'Payment Mode',
              value: draft.paymentMode.displayLabel,
            ),
            const Divider(),
            _ReviewRow(
              label: 'You Pay (at pickup)',
              value: draft.paymentMode == PaymentMode.receiverPays
                  ? '₦0'
                  : (draft.paymentMode == PaymentMode.splitPayment
                      ? draft.senderPaymentAmount?.formatted ?? '₦0'
                      : totalPrice.formatted),
            ),
            const Divider(),
            _ReviewRow(
              label: 'Receiver Pays (at delivery)',
              value: draft.paymentMode == PaymentMode.senderPays
                  ? '₦0'
                  : (draft.paymentMode == PaymentMode.splitPayment &&
                          draft.senderPaymentAmount != null
                      ? (totalPrice - draft.senderPaymentAmount!).formatted
                      : totalPrice.formatted),
            ),
          ],
        ),

        const SizedBox(height: CereloSpacing.lg),

        // Final Request Button
        CereloButton(
          label: draft.isSubmitting ? 'Creating shipment...' : 'Request Delivery',
          isLoading: draft.isSubmitting,
          variant: CereloButtonVariant.primary,
          onPressed: draft.isSubmitting
              ? null
              : () async {
                  final shipment = await notifier.submitShipmentRequest();
                  if (shipment != null && context.mounted) {
                    // Reset the draft so the NEXT shipment gets a fresh
                    // idempotency key.  Do this BEFORE navigation so the
                    // autoDispose provider does not rebuild mid-navigation.
                    notifier.reset();
                    // Navigate using GoRouter — keeps the navigation stack
                    // consistent so "Back to Home" inside the success screen
                    // always works, and the shipment wizard is removed from
                    // the back-stack via pushReplacement.
                    context.pushReplacement(
                      AppRoutes.sendPackageSuccess,
                      extra: shipment,
                    );
                  }
                },
        ),

        const SizedBox(height: CereloSpacing.md),

        const Text(
          'By requesting, you agree that Cerelo personnel will physically verify package size and collect physical payment at pickup.',
          style: TextStyle(
            fontSize: 11,
            color: CereloColors.textTertiary,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PaymentOptionCard extends StatelessWidget {
  const _PaymentOptionCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: CereloSpacing.sm),
      decoration: BoxDecoration(
        color: isSelected
            ? CereloColors.orange.withOpacity(0.04)
            : CereloColors.white,
        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
        border: Border.all(
          color: isSelected ? CereloColors.orange : CereloColors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          isSelected
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_off_rounded,
          color:
              isSelected ? CereloColors.orange : CereloColors.textTertiary,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: CereloColors.navy,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: CereloColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ReviewSectionCard extends StatelessWidget {
  const _ReviewSectionCard({
    required this.title,
    required this.onEdit,
    required this.children,
  });

  final String title;
  final VoidCallback onEdit;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CereloSpacing.md),
      decoration: BoxDecoration(
        color: CereloColors.white,
        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
        border: Border.all(color: CereloColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: CereloColors.navy,
                ),
              ),
              GestureDetector(
                onTap: onEdit,
                child: const Text(
                  'Edit',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CereloColors.orangeDark,
                  ),
                ),
              ),
            ],
          ),
          const Divider(),
          ...children,
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
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
      padding: const EdgeInsets.symmetric(vertical: 3),
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
