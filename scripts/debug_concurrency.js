/**
 * DEPRECATED - HISTORICAL ONE-OFF SCRIPT
 * NOT APPROVED FOR DIRECT TEST EXECUTION.
 * Use scripts/lib/safe_test_db_client.js for all approved destructive operations.
 */
console.error('[ERROR] This historical script is deprecated and cannot be run directly.');
process.exit(1);


const adminClient = createClient(HOSTED_URL, SERVICE_KEY, { auth: { autoRefreshToken: false, persistSession: false } });

async function debug() {
  const ts = Date.now();
  const sEmail = `dbg_s_${ts}@test.cerelonet.com`;
  const pEmail = `dbg_p_${ts}@test.cerelonet.com`;

  const { data: su } = await adminClient.auth.admin.createUser({ email: sEmail, password: 'Password123!', email_confirm: true, user_metadata: { full_name: 'Debug Sender' }, app_metadata: { role: 'customer' } });
  const { data: pu } = await adminClient.auth.admin.createUser({ email: pEmail, password: 'Password123!', email_confirm: true, user_metadata: { full_name: 'Debug Staff' }, app_metadata: { role: 'personnel' } });

  const { data: hubs } = await adminClient.from('operating_hubs').select('*');
  await adminClient.from('personnel').insert({ id: pu.user.id, full_name: 'Debug Staff', phone_number: `+234807${ts.toString().slice(-7)}`, employee_reference: `EMP-${ts.toString().slice(-4)}`, operating_hub_id: hubs[0].id, is_active: true });

  const sClient = createClient(HOSTED_URL, HOSTED_ANON_KEY);
  await sClient.auth.signInWithPassword({ email: sEmail, password: 'Password123!' });
  const pClient = createClient(HOSTED_URL, HOSTED_ANON_KEY);
  await pClient.auth.signInWithPassword({ email: pEmail, password: 'Password123!' });

  await sClient.rpc('complete_customer_onboarding', { p_account_type: 'INDIVIDUAL', p_full_name: 'Debug Sender' });

  const { data: ship, error: shipErr } = await sClient.rpc('create_shipment_request', {
    p_origin_city: 'Kano', p_destination_city: 'Katsina',
    p_sender_pickup_address: 'Kwari', p_receiver_name: 'Recv', p_receiver_phone: '+2348090001122', p_receiver_delivery_address: 'Kat',
    p_parcel_size_code: 'SMALL', p_category_description: 'Test', p_payment_mode: 'SENDER_PAYS',
    p_sender_payment_amount: 200000, p_idempotency_key: `req_${ts}`
  });
  console.log('Shipment:', ship, shipErr);

  const [rA, rB] = await Promise.all([
    pClient.rpc('record_physical_payment', { p_shipment_id: ship.id, p_payer_party: 'SENDER', p_amount: 200000, p_method: 'CASH', p_idempotency_key: `dbg_pay_A_${ts}` }),
    pClient.rpc('record_physical_payment', { p_shipment_id: ship.id, p_payer_party: 'SENDER', p_amount: 200000, p_method: 'CASH', p_idempotency_key: `dbg_pay_B_${ts}` })
  ]);
  console.log('rA:', rA);
  console.log('rB:', rB);

  const { data: collections } = await adminClient.from('payment_collections').select('*').eq('shipment_id', ship.id);
  console.log('Collections count:', collections.length, collections);

  const { data: obs } = await adminClient.from('payment_obligations').select('*').eq('shipment_id', ship.id);
  console.log('Obligation status:', obs);
}

debug().catch(err => console.error(err));
