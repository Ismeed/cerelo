import { describe, it, expect } from 'vitest'
import { formatNaira, maskPhoneNumber, formatNigerianTime } from './utils'

describe('formatNaira', () => {
  it('formats 300000 kobo as ₦3,000', () => {
    expect(formatNaira(300000)).toBe('₦3,000')
  })

  it('formats 0 kobo as ₦0', () => {
    expect(formatNaira(0)).toBe('₦0')
  })

  it('formats kobo remainder correctly', () => {
    expect(formatNaira(300050)).toBe('₦3,000.50')
  })

  it('formats large amount correctly', () => {
    expect(formatNaira(1000000)).toBe('₦10,000')
  })
})

describe('maskPhoneNumber', () => {
  it('masks middle digits of Nigerian phone', () => {
    const masked = maskPhoneNumber('+2348012345678')
    expect(masked).toContain('***')
    expect(masked).toContain('+234801')
    expect(masked).toContain('5678')
  })

  it('handles short input gracefully', () => {
    expect(maskPhoneNumber('123')).toBe('***')
  })
})

describe('formatNigerianTime', () => {
  it('returns a non-empty string for a valid ISO date', () => {
    const result = formatNigerianTime('2026-08-17T10:00:00Z')
    expect(result).toBeTruthy()
    expect(typeof result).toBe('string')
  })
})
