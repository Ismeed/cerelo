'use client'

import { useState, Suspense } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { createBrowserSupabaseClient } from '@/lib/supabase/browser'

function LoginForm() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const errorParam = searchParams.get('error')
  const redirectTo = searchParams.get('redirectTo') || '/dashboard/overview'

  const [email, setEmail] = useState('')
  const [otp, setOtp] = useState('')
  const [step, setStep] = useState<'EMAIL' | 'OTP'>('EMAIL')
  const [loading, setLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(
    errorParam === 'unauthorized' ? 'Your account does not have admin access.' : null
  )
  const [successMessage, setSuccessMessage] = useState<string | null>(null)

  const supabase = createBrowserSupabaseClient()

  const handleSendOtp = async (e: React.FormEvent) => {
    e.preventDefault()
    setErrorMessage(null)
    setSuccessMessage(null)
    const cleanEmail = email.trim().toLowerCase()

    if (!cleanEmail || !cleanEmail.includes('@')) {
      setErrorMessage('Please enter a valid internal admin email address.')
      return
    }

    setLoading(true)
    try {
      const { error } = await supabase.auth.signInWithOtp({
        email: cleanEmail,
        options: {
          shouldCreateUser: false,
        },
      })

      if (error) {
        if (
          error.message.toLowerCase().includes('signups not allowed') ||
          error.message.toLowerCase().includes('user not found')
        ) {
          setErrorMessage('Access Denied: This email is not registered as an internal Admin account.')
        } else {
          setErrorMessage(error.message)
        }
      } else {
        setSuccessMessage(`A 6-digit authentication code has been sent to ${cleanEmail}.`)
        setStep('OTP')
      }
    } catch {
      setErrorMessage('Network error while requesting authentication code. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  const handleVerifyOtp = async (e: React.FormEvent) => {
    e.preventDefault()
    setErrorMessage(null)
    setSuccessMessage(null)
    const cleanOtp = otp.trim().replace(/\D/g, '')

    if (cleanOtp.length !== 6) {
      setErrorMessage('Please enter the exact 6-digit verification code.')
      return
    }

    setLoading(true)
    try {
      const { data, error } = await supabase.auth.verifyOtp({
        email: email.trim().toLowerCase(),
        token: cleanOtp,
        type: 'email',
      })

      if (error) {
        setErrorMessage(error.message || 'Invalid or expired authentication code.')
        setLoading(false)
        return
      }

      if (!data.user) {
        setErrorMessage('Authentication failed. Please try again.')
        setLoading(false)
        return
      }

      // Check admin authorization from app_metadata
      const role = data.user.app_metadata?.role
      if (role !== 'admin' && role !== 'ADMIN') {
        await supabase.auth.signOut()
        setErrorMessage('Unauthorized: Your account does not have Admin access privileges.')
        setStep('EMAIL')
        setLoading(false)
        return
      }

      // Successful admin login
      router.push(redirectTo)
      router.refresh()
    } catch {
      setErrorMessage('An unexpected error occurred during verification.')
      setLoading(false)
    }
  }

  return (
    <main className="min-h-screen flex items-center justify-center bg-cerelo-navy px-4">
      <div className="w-full max-w-md">
        {/* Brand Header */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-cerelo-orange text-white font-black text-2xl tracking-wider mb-3 shadow-lg">
            C
          </div>
          <h1 className="text-3xl font-extrabold text-white tracking-tight">
            Cerelo Operations
          </h1>
          <p className="text-white/70 mt-1 text-sm tracking-wide">
            Internal Operations Admin Portal
          </p>
        </div>

        {/* Feedback Messages */}
        {errorMessage && (
          <div className="bg-red-500/10 border border-red-500/30 rounded-xl p-4 mb-6">
            <p className="text-red-300 text-sm text-center font-medium">
              {errorMessage}
            </p>
          </div>
        )}

        {successMessage && (
          <div className="bg-emerald-500/10 border border-emerald-500/30 rounded-xl p-4 mb-6">
            <p className="text-emerald-300 text-sm text-center font-medium">
              {successMessage}
            </p>
          </div>
        )}

        {/* Auth Card */}
        <div className="bg-white rounded-2xl p-8 shadow-2xl border border-white/10 space-y-6">
          {step === 'EMAIL' ? (
            <form onSubmit={handleSendOtp} className="space-y-4">
              <div>
                <label className="block text-xs font-bold text-text-secondary uppercase tracking-wider mb-2">
                  Internal Admin Email
                </label>
                <input
                  type="email"
                  required
                  autoFocus
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="name@cerelonet.com"
                  className="w-full px-4 py-3 border border-border rounded-xl text-sm font-medium text-text-primary focus:outline-none focus:ring-2 focus:ring-cerelo-navy/20 focus:border-cerelo-navy transition"
                />
                <p className="text-xs text-text-tertiary mt-2">
                  Only authorized internal administrators may sign in.
                </p>
              </div>

              <button
                type="submit"
                disabled={loading || !email.trim()}
                className="w-full py-3.5 px-4 bg-cerelo-navy hover:bg-cerelo-navy/90 text-white rounded-xl text-sm font-bold shadow-md transition disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {loading ? 'Sending Code...' : 'Send 6-Digit OTP Code'}
              </button>
            </form>
          ) : (
            <form onSubmit={handleVerifyOtp} className="space-y-4">
              <div>
                <div className="flex items-center justify-between mb-2">
                  <label className="block text-xs font-bold text-text-secondary uppercase tracking-wider">
                    Enter 6-Digit Code
                  </label>
                  <button
                    type="button"
                    onClick={() => {
                      setStep('EMAIL')
                      setOtp('')
                      setErrorMessage(null)
                    }}
                    className="text-xs font-bold text-cerelo-orange hover:underline"
                  >
                    Change Email
                  </button>
                </div>
                <input
                  type="text"
                  required
                  autoFocus
                  maxLength={6}
                  value={otp}
                  onChange={(e) => setOtp(e.target.value.replace(/\D/g, ''))}
                  placeholder="123456"
                  className="w-full px-4 py-3 border border-border rounded-xl text-center font-mono text-2xl tracking-[0.5em] font-bold text-text-primary focus:outline-none focus:ring-2 focus:ring-cerelo-navy/20 focus:border-cerelo-navy transition"
                />
                <p className="text-xs text-text-tertiary mt-2 text-center">
                  Sent to <span className="font-semibold text-text-secondary">{email}</span>
                </p>
              </div>

              <button
                type="submit"
                disabled={loading || otp.trim().length !== 6}
                className="w-full py-3.5 px-4 bg-cerelo-orange hover:bg-cerelo-orange/90 text-white rounded-xl text-sm font-bold shadow-md transition disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {loading ? 'Verifying...' : 'Verify & Enter Dashboard'}
              </button>

              <div className="pt-2 text-center">
                <button
                  type="button"
                  disabled={loading}
                  onClick={handleSendOtp}
                  className="text-xs font-semibold text-text-secondary hover:text-text-primary underline"
                >
                  Didn’t receive code? Resend OTP
                </button>
              </div>
            </form>
          )}
        </div>

        {/* Footer Note */}
        <div className="text-center mt-6">
          <p className="text-xs text-white/50">
            Cerelo Logistics Network · Protected by Row Level Security & Server Audit
          </p>
        </div>
      </div>
    </main>
  )
}

export default function LoginPage() {
  return (
    <Suspense fallback={<div className="min-h-screen bg-cerelo-navy flex items-center justify-center text-white text-sm font-bold">Loading Cerelo Admin...</div>}>
      <LoginForm />
    </Suspense>
  )
}
