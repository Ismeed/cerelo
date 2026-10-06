/**
 * CERELO SUPABASE SECRET KEY CONFIGURATION
 * =========================================
 * Non-secret configuration for the Supabase new API key model.
 *
 * WHY THIS FILE EXISTS:
 * Supabase automatically injects SUPABASE_SECRET_KEYS (a JSON dictionary)
 * into all hosted Edge Functions. This dictionary contains all named API keys
 * created for the project. Key NAMES are not secret — only key VALUES are.
 *
 * This file records the non-secret name of the active Staging backend key so
 * that Edge Functions can look it up from the dictionary without hardcoding a
 * guess or requiring an additional custom environment variable.
 *
 * HOW TO UPDATE:
 * When a new API key is created in the Supabase Dashboard, update
 * CERELO_STAGING_SECRET_KEY_NAME below to match its exact name.
 */

export const CERELO_STAGING_SECRET_KEY_NAME = 'cerelo_staging_backend_2026_08';
