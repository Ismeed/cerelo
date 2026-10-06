/**
 * Centralized Legal & Regulatory Configuration — CERELO V1
 *
 * IMPORTANT:
 * - All entries in this file represent authoritative legal facts.
 * - If an item is unconfirmed or pending legal/corporate verification,
 *   it MUST be set to null. NEVER fabricate corporate registration details,
 *   RC numbers, physical registered offices, or unverified support mailboxes.
 */

export interface LegalConfig {
  /** Registered corporate entity name if confirmed (null = pending legal confirmation) */
  legalEntityName: string | null;
  /** Public brand and trading name */
  tradingName: string;
  /** Formal registered business address (null = pending confirmation) */
  registeredAddress: string | null;
  /** Operating country */
  country: string;
  /** Legal jurisdiction */
  jurisdiction: string;
  /** Designated privacy contact email (null = channel pending activation) */
  privacyContact: string | null;
  /** Designated legal/contracts contact email (null = channel pending activation) */
  legalContact: string | null;
  /** Operations support contact email (null = channel pending activation) */
  supportContact: string | null;
  /** Policy version */
  privacyVersion: string;
  /** Terms version */
  termsVersion: string;
  /** Privacy effective date string */
  privacyEffectiveDate: string;
  /** Terms effective date string */
  termsEffectiveDate: string;
  /** Flag indicating documents are working operational drafts awaiting legal counsel sign-off */
  isDraftPendingApproval: boolean;
  /** Operating corridor description */
  corridorName: string;
}

export const LEGAL_CONFIG: LegalConfig = {
  legalEntityName: null, // PENDING FORMAL LEGAL CONFIRMATION
  tradingName: 'CERELO',
  registeredAddress: null, // PENDING FORMAL LEGAL CONFIRMATION
  country: 'Nigeria',
  jurisdiction: 'Federal Republic of Nigeria',
  privacyContact: null, // PENDING DEDICATED PRIVACY CHANNEL ACTIVATION
  legalContact: null, // PENDING DEDICATED LEGAL CHANNEL ACTIVATION
  supportContact: null, // PENDING PRODUCTION SUPPORT CHANNEL ACTIVATION
  privacyVersion: '1.0.0-draft',
  termsVersion: '1.0.0-draft',
  privacyEffectiveDate: 'Pending Formal Legal Approval & Publication',
  termsEffectiveDate: 'Pending Formal Legal Approval & Publication',
  isDraftPendingApproval: true,
  corridorName: 'Kano ↔ Katsina Corridor',
};
