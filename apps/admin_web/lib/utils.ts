import { type ClassValue, clsx } from 'clsx'
import { twMerge } from 'tailwind-merge'

/** Merges Tailwind CSS class names safely. */
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

/**
 * Formats a Nigerian Naira amount from kobo (minor units) to display string.
 * Matches the Money.formatted behavior in cerelo_core Dart package.
 * @param kobo - Amount in kobo (integer, never float)
 */
export function formatNaira(kobo: number): string {
  const naira = Math.floor(kobo / 100)
  const koboRemainder = kobo % 100
  const nairaStr = naira.toLocaleString('en-NG')
  if (koboRemainder === 0) {
    return `₦${nairaStr}`
  }
  return `₦${nairaStr}.${koboRemainder.toString().padStart(2, '0')}`
}

/**
 * Formats a UTC ISO timestamp to Nigerian local time (WAT = UTC+1).
 */
export function formatNigerianTime(isoString: string): string {
  return new Intl.DateTimeFormat('en-NG', {
    timeZone: 'Africa/Lagos',
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(isoString))
}

/**
 * Masks a phone number for safe display in restricted views.
 * Example: +2348012345678 → +234 801 ***5678
 * SECURITY: Never show full phone numbers in shared/public views.
 */
export function maskPhoneNumber(phone: string): string {
  if (phone.length < 8) return '***'
  return `${phone.substring(0, 8)}***${phone.substring(phone.length - 4)}`
}
