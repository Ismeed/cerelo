# CERELO Website — Production Technical Readiness & Domain Architecture

> **Status**: PROMPT 9B2 VERIFIED & DOMAIN CONNECTED  
> **Canonical Domain**: `https://cerelonet.com`  
> **Release Stage**: `prelaunch` (Search indexing disabled)  
> **Backend Project**: `cerelo-production` (`mgffdifedhquwiirkhyy` in `eu-west-1`)  
> **Last Verified**: 2026-08-22  

---

## 1. Domain & Routing Architecture

- **Canonical URL**: `https://cerelonet.com`
- **Subdomain Routing**: `https://www.cerelonet.com` → `308 Permanent Redirect` → `https://cerelonet.com/`
- **Insecure HTTP Routing**: `http://cerelonet.com` & `http://www.cerelonet.com` → `308 Permanent Redirect` → `https://cerelonet.com/`
- **Hosting Platform**: Vercel (`cerelo-website` / `prj_oDOGwu5Ud6uMpOKTAb5QA8i3uPxB`)
- **DNS Host**: Namecheap Advanced DNS
  - Apex A Record: `216.198.79.1`
  - www CNAME: `75c42407850c19c0.vercel-dns-017.com.`

---

## 2. Environment & Backend Separation

- **Production Vercel Deployment**:
  - `NEXT_PUBLIC_SUPABASE_URL`: `https://mgffdifedhquwiirkhyy.supabase.co`
  - `NEXT_PUBLIC_SUPABASE_ANON_KEY`: Cerelo Production Anon Key
  - `NEXT_PUBLIC_RELEASE_STAGE`: `prelaunch`
  - `NEXT_PUBLIC_ENV`: `production`
- **Preview & Development Deployments**:
  - `NEXT_PUBLIC_SUPABASE_URL`: `https://plsoyomwoqysharmuddl.supabase.co` (cerelo-staging)
  - `NEXT_PUBLIC_SUPABASE_ANON_KEY`: Cerelo Staging Anon Key
  - Zero cross-contamination with production database.

---

## 3. Security, Privacy & Compliance Controls

1. **Search Indexing**:
   - `robots.txt`: `User-Agent: * \n Disallow: /`
   - `X-Robots-Tag`: `noindex, nofollow`
   - HTML Meta Robots: `noindex, nofollow`
   - Controlled by `NEXT_PUBLIC_RELEASE_STAGE !== 'live'`
2. **Content Security Policy (CSP)**:
   - Restricts `img-src` and `connect-src` strictly to `self` and the configured Supabase backend (`mgffdifedhquwiirkhyy.supabase.co`).
   - Frame ancestors: `none` (anti-clickjacking).
3. **Public Tracking Privacy**:
   - Zero PII emitted at database SQL level (`get_public_shipment_tracking`).
   - Minimal projection keys only.
4. **Email Infrastructure**:
   - Resend DKIM (`resend._domainkey`) and DMARC (`_dmarc`) active on `cerelonet.com`.
   - Production custom SMTP active via `smtp.resend.com:465` (`CERELO <auth@cerelonet.com>`).

---

## 4. Remaining Commercial Launch Gate Blockers (Pre-Launch Status)

Connecting the official domain is a **technical milestone** and does **not** constitute commercial launch authorization:
- ❌ **Commercial Pricing**: `pricing_rules.is_approved_for_production = FALSE` across all tiers.
- ❌ **Search Engine Indexing**: Blocked by `noindex` until Prompt 10.
- ❌ **Customer Mobile App**: Remains unpointed to production.
- ❌ **Admin Operations Web**: Unattached to production (`admin.cerelonet.com` not deployed).
- ❌ **Regulatory / Legal Clearances**: Formal courier licensing, goods-in-transit insurance, NDPA determinations pending final executive sign-off.
