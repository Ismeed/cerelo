'use server'

import { createClient } from '@supabase/supabase-js'
import { requireAdminSession } from '@/lib/auth/session'
import type { PersonnelProvisionInput } from '@/types/admin'

export async function provisionPersonnelAction(input: PersonnelProvisionInput) {
  try {
    const session = await requireAdminSession()

    const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL

    if (!serviceRoleKey || !supabaseUrl) {
      return { success: false, error: 'Server configuration error: Missing service credentials.' }
    }

    const cleanEmail = input.email.trim().toLowerCase()
    const cleanName = input.fullName.trim()
    const cleanPhone = input.phoneNumber.trim()
    const cleanRef = input.employeeReference.trim()
    const hubId = input.operatingHubId.trim()

    if (!cleanEmail || !cleanName || !cleanPhone || !cleanRef || !hubId) {
      return { success: false, error: 'All fields are mandatory for personnel provisioning.' }
    }

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    })

    // 1. Create auth user with role = 'personnel' and no password (Email OTP only)
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: cleanEmail,
      email_confirm: true,
      user_metadata: {
        full_name: cleanName,
      },
      app_metadata: {
        role: 'personnel',
      },
    })

    if (authError || !authData.user) {
      return { success: false, error: authError?.message || 'Failed to create auth identity.' }
    }

    const userId = authData.user.id

    // 2. Insert into public.personnel
    const { error: insertError } = await supabaseAdmin.from('personnel').insert({
      id: userId,
      full_name: cleanName,
      phone_number: cleanPhone,
      employee_reference: cleanRef,
      operating_hub_id: hubId,
      is_active: true,
    })

    if (insertError) {
      // Rollback auth user
      await supabaseAdmin.auth.admin.deleteUser(userId)
      return { success: false, error: `Database error: ${insertError.message}` }
    }

    // 3. Log immutable admin audit event
    await supabaseAdmin.from('admin_audit_logs').insert({
      actor_user_id: session.userId,
      actor_email: session.email || 'admin@cerelonet.com',
      action: 'PROVISION_PERSONNEL',
      aggregate_type: 'PERSONNEL',
      aggregate_id: userId,
      reason: `Provisioned staff member ${cleanName} (${cleanRef}) to hub ${hubId}`,
      after_state: {
        id: userId,
        email: cleanEmail,
        full_name: cleanName,
        phone_number: cleanPhone,
        employee_reference: cleanRef,
        operating_hub_id: hubId,
        is_active: true,
      },
    })

    return {
      success: true,
      personnel: {
        id: userId,
        email: cleanEmail,
        fullName: cleanName,
        employeeReference: cleanRef,
      },
    }
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Internal server action error'
    return { success: false, error: message }
  }
}
