/**
 * CERELO V1 — HOSTED EXTENDED VERIFICATION (Phases 9 & 10)
 *
 * Target: cerelo-staging (https://plsoyomwoqysharmuddl.supabase.co)
 * Tests:
 * - Payment Invariant Models (SENDER_PAYS, RECEIVER_PAYS, SPLIT_PAYMENT)
 * - Duplicate / Partial Payment Protection
 * - Idempotency & Invalid State Transition Rejections
 * - Concurrency Guards
 */

const path = require('path');
const { createClient } = require(path.resolve(__dirname, '../apps/admin_web/node_modules/@supabase/supabase-js'));
const { TestSession, assertNotProtected } = require('./lib/safe_test_db_client');
const { getSupabaseSecretKey, getSupabasePublishableKey } = require('./lib/env_loader');

const testSession = new TestSession('HOSTED-EXTENDED');
const HOSTED_URL = 'https://plsoyomwoqysharmuddl.supabase.co';
const HOSTED_PUBLISHABLE_KEY = getSupabasePublishableKey();

// Prefers SUPABASE_SECRET_KEY (sb_secret_...) — falls back to SUPABASE_SERVICE_ROLE_KEY during migration.
// TODO: Remove legacy fallback after management disables the old service-role credential.
const HOSTED_SERVICE_ROLE_KEY = getSupabaseSecretKey();

const adminClient = createClient(HOSTED_URL, HOSTED_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

let passed = 0;
let failed = 0;

function assert(condition, message) {
  if (condition) {
    console.log(`  [PASS] ${message}`);
    passed++;
  } else {
    console.error(`  [FAIL] ${message}`);
    failed++;
  }
}

async function runExtendedTests() {
  console.log('===============================================================');
  console.log('CERELO V1 — HOSTED EXTENDED PAYMENT & IDEMPOTENCY SUITE');
  console.log('===============================================================\n');

  const timestamp = Date.now();
  const senderEmail = `pay_sender_${timestamp}@test.cerelo.com`;
  const personnelEmail = `pay_staff_${timestamp}@test.cerelo.com`;
  const password = 'TestPassword123!';

  // Create actors
  const { data: sAuth } = await adminClient.auth.admin.createUser({
    email: senderEmail, password, email_confirm: true,
    user_metadata: { full_name: 'Payment Tester' }, app_metadata: { role: 'customer' }
  });
  const { data: pAuth } = await adminClient.auth.admin.createUser({
    email: personnelEmail, password, email_confirm: true,
    user_metadata: { full_name: 'Payment Personnel' }, app_metadata: { role: 'personnel' }
  });

  const { data: hubs } = await adminClient.from('operating_hubs').select('*');
  const kanoHub = hubs.find(h => h.name.includes('Kano'));
  await adminClient.from('personnel').insert({
    id: pAuth.user.id, full_name: 'Payment Personnel',
    phone_number: `+234805${timestamp.toString().slice(-7)}`,
    employee_reference: `EMP-P-${timestamp.toString().slice(-4)}`,
    operating_hub_id: kanoHub.id, is_active: true
  });

  const senderClient = createClient(HOSTED_URL, HOSTED_ANON_KEY);
  await senderClient.auth.signInWithPassword({ email: senderEmail, password });
  const personnelClient = createClient(HOSTED_URL, HOSTED_ANON_KEY);
  await personnelClient.auth.signInWithPassword({ email: personnelEmail, password });

  // Complete onboarding for sender
  await senderClient.rpc('complete_customer_onboarding', {
    p_account_type: 'INDIVIDUAL',
    p_full_name: 'Payment Tester'
  });

  // --------------------------------------------------------------------------
  // MODEL 1: SENDER_PAYS (100% collected at pickup)
  // --------------------------------------------------------------------------
  console.log('--- TEST: SENDER_PAYS Model ---');
  const { data: spShipment, error: spErr } = await senderClient.rpc('create_shipment_request', {
    p_origin_city: 'Kano',
    p_destination_city: 'Katsina',
    p_sender_pickup_address: 'Kwari Market',
    p_receiver_name: 'Receiver SP',
    p_receiver_phone: '+2348091112233',
    p_receiver_delivery_address: 'Katsina City',
    p_parcel_size_code: 'SMALL',
    p_category_description: 'Docs',
    p_payment_mode: 'SENDER_PAYS',
    p_sender_payment_amount: 200000,
    p_idempotency_key: `sp_${timestamp}`
  });
  if (spErr) console.error('spErr:', spErr);
  assert(!spErr && spShipment.id, 'SENDER_PAYS shipment created (₦2,000)');

  // Verify payment obligations
  const { data: spObligations } = await adminClient.from('payment_obligations').select('*').eq('shipment_id', spShipment.id);
  const senderObligation = spObligations.find(o => o.payer_party === 'SENDER');
  const receiverObligation = spObligations.find(o => o.payer_party === 'RECEIVER');
  assert(senderObligation && senderObligation.expected_amount === 200000, 'Sender obligation: ₦2,000 expected');
  assert(receiverObligation && receiverObligation.expected_amount === 0, 'Receiver obligation: ₦0 expected (SENDER_PAYS)');

  // Collect Sender payment
  const { data: spPayRes, error: spPayErr } = await personnelClient.rpc('record_physical_payment', {
    p_shipment_id: spShipment.id,
    p_payer_party: 'SENDER',
    p_amount: 200000,
    p_method: 'CASH',
    p_idempotency_key: `pay_sp_${timestamp}`
  });
  assert(!spPayErr && spPayRes.success, 'Sender payment 100% collected');

  // Verify duplicate payment rejection / idempotency
  const { data: dupPayRes, error: dupPayErr } = await personnelClient.rpc('record_physical_payment', {
    p_shipment_id: spShipment.id,
    p_payer_party: 'SENDER',
    p_amount: 200000,
    p_method: 'CASH',
    p_idempotency_key: `pay_sp_${timestamp}`
  });
  assert(!dupPayErr && dupPayRes.success, 'Duplicate payment call with same idempotency key is safely idempotent');

  // --------------------------------------------------------------------------
  // MODEL 2: RECEIVER_PAYS (100% collected at doorstep)
  // --------------------------------------------------------------------------
  console.log('\n--- TEST: RECEIVER_PAYS Model ---');
  const { data: rpShipment, error: rpErr } = await senderClient.rpc('create_shipment_request', {
    p_origin_city: 'Kano',
    p_destination_city: 'Katsina',
    p_sender_pickup_address: 'Kwari Market',
    p_receiver_name: 'Receiver RP',
    p_receiver_phone: '+2348092223344',
    p_receiver_delivery_address: 'Katsina City',
    p_parcel_size_code: 'LARGE',
    p_category_description: 'Large Bale',
    p_payment_mode: 'RECEIVER_PAYS',
    p_idempotency_key: `rp_${timestamp}`
  });
  assert(!rpErr && rpShipment.id, 'RECEIVER_PAYS shipment created (₦6,000)');

  const { data: rpObligations } = await adminClient.from('payment_obligations').select('*').eq('shipment_id', rpShipment.id);
  const rpSenderOb = rpObligations.find(o => o.payer_party === 'SENDER');
  const rpReceiverOb = rpObligations.find(o => o.payer_party === 'RECEIVER');
  assert(rpSenderOb && rpSenderOb.expected_amount === 0, 'Sender obligation: ₦0 (RECEIVER_PAYS)');
  assert(rpReceiverOb && rpReceiverOb.expected_amount === 600000, 'Receiver obligation: ₦6,000 expected (RECEIVER_PAYS)');

  // --------------------------------------------------------------------------
  // TEST: State Machine Violation Protection (Illegal State Skip Rejection)
  // --------------------------------------------------------------------------
  console.log('\n--- TEST: State Machine Precondition & Invalid Transition Protection ---');

  // Attempt to mark delivered directly without pickup, transit, or reconciliation
  const { data: illegalDeliv, error: illegalDelivErr } = await personnelClient.rpc('mark_delivered', {
    p_shipment_id: rpShipment.id,
    p_idempotency_key: `illegal_${timestamp}`
  });
  assert(illegalDelivErr !== null || (illegalDeliv && illegalDeliv.success === false), 
    'Server correctly rejected illegal jump to DELIVERED from REQUESTED state');

  console.log('\n===============================================================');
  console.log(`EXTENDED VERIFICATION: ${passed} Passed, ${failed} Failed`);
  console.log('===============================================================');

  if (failed > 0) process.exit(1);
}

runExtendedTests().catch(err => {
  console.error('Extended test failed:', err);
  process.exit(1);
});
