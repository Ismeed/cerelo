# Cerelo

> **Intercity door-to-door parcel logistics platform — Kano ↔ Katsina**

Cerelo is a technology-enabled intercity logistics platform that enables senders to book door-to-door parcel delivery between Kano and Katsina, Nigeria. Cerelo field Personnel handle pickup, consolidation, middle-mile transit, destination reconciliation, and final-mile doorstep delivery — all tracked through a mobile-first digital platform.

---

## V1 Scope

Cerelo V1 is scoped exclusively to the **Kano ↔ Katsina intercity corridor**. See [`docs/CERELO_V1_REQUIREMENTS_FREEZE.md`](docs/CERELO_V1_REQUIREMENTS_FREEZE.md) for the complete frozen scope.

---

## Applications

| Application | Platform | Purpose |
|:---|:---|:---|
| `apps/customer_app` | Flutter (Android/iOS) | Customer parcel request, tracking, sharing, receipt |
| `apps/personnel_app` | Flutter (Android/iOS) | Field Personnel operations, QR scanning, payments |
| `apps/admin_web` | Next.js (Web/PWA) | Admin/Operations management panel |

---

## Selected Stack

| Layer | Technology |
|:---|:---|
| Mobile Framework | Flutter (Dart) — Melos monorepo |
| Web Framework | Next.js 14 (App Router / TypeScript) |
| Backend Platform | Supabase Cloud (PostgreSQL 15+, Auth, Edge Functions, Storage) |
| Authentication | Supabase Auth (Google OAuth + Email) |
| Push Notifications | Firebase Cloud Messaging (FCM) |
| Admin Hosting | Vercel |
| Package Manager (JS) | pnpm |
| Monorepo Tool (Dart) | Melos |

---

## Prerequisites

### All developers
- Git
- [Flutter SDK](https://flutter.dev/docs/get-started/install) >= 3.22.0
- Dart >= 3.4.0
- [Melos](https://melos.invertase.dev/) — `dart pub global activate melos`
- [Node.js](https://nodejs.org/) >= 20.x (LTS)
- [pnpm](https://pnpm.io/) — `npm install -g pnpm`
- [Supabase CLI](https://supabase.com/docs/guides/cli) >= 1.200.0

### Backend / Database
- Docker Desktop (required for local Supabase)

---

## Environment Setup

**1. Copy environment examples:**
```bash
# Admin web
cp apps/admin_web/.env.example apps/admin_web/.env.local

# Edge functions (local development)
cp supabase/.env.example supabase/.env.local
```

**2. Fill in values** — see each `.env.example` for required variables. Never commit real secrets.

**3. Start local Supabase:**
```bash
supabase start
```
This starts a local PostgreSQL, Auth, and Storage instance. The CLI will output your local project URL and anon key.

**4. Run migrations:**
```bash
supabase db reset
```

---

## Installation

```bash
# Install all dependencies (Dart + JS)
pnpm install          # JS dependencies (admin_web + root)
melos bootstrap       # Dart dependencies (Flutter apps + packages)
```

---

## Local Development

### Run all apps concurrently
```bash
pnpm dev
```

### Run individual surfaces
```bash
pnpm dev:admin        # Next.js admin web on http://localhost:3000
pnpm dev:backend      # Start local Supabase (alias for supabase start)

# Flutter apps (run in separate terminals or via IDE)
cd apps/customer_app && flutter run
cd apps/personnel_app && flutter run
```

---

## Testing

```bash
# All Dart tests
melos run test

# Dart static analysis
melos run analyze

# Admin web tests
pnpm --filter admin_web test

# Admin web lint + typecheck
pnpm lint
pnpm typecheck
```

---

## Database

```bash
supabase start              # Start local database
supabase db reset           # Apply all migrations fresh
supabase migration new      # Create new migration file
supabase gen types typescript --local > apps/admin_web/lib/database.types.ts
```

> ⚠️ **Never manually modify production schema.** Always use migration files.

---

## Build

```bash
# Admin web production build
pnpm --filter admin_web build

# Flutter release builds (from respective app directory)
flutter build apk --release
flutter build ios --release
```

---

## Project Structure

```
cerelo/
├── AGENTS.md               # AI agent guardrails (READ THIS FIRST)
├── README.md               # This file
├── melos.yaml              # Flutter monorepo config
├── pnpm-workspace.yaml     # JS monorepo config
│
├── apps/
│   ├── customer_app/       # Flutter Customer mobile app
│   ├── personnel_app/      # Flutter Personnel mobile app
│   └── admin_web/          # Next.js Admin operations web app
│
├── packages/
│   ├── cerelo_core/        # Shared Dart: domain types, enums, validation
│   ├── cerelo_api/         # Shared Dart: Supabase API client, DTOs
│   └── cerelo_ui/          # Shared Dart: design system, widgets
│
├── supabase/
│   ├── config.toml         # Local Supabase CLI config
│   ├── migrations/         # Version-controlled SQL migrations
│   ├── functions/          # Deno Edge Functions
│   └── seed.sql            # Development seed data
│
└── docs/                   # Architecture & product documents
    ├── adr/                # Architectural Decision Records
    └── *.md                # Approved specification documents
```

---

## Architecture Documents

All product and technical decisions are documented in `/docs`:

| Document | Purpose |
|:---|:---|
| `docs/CERELO_PRODUCT_CONTEXT.md` | What Cerelo is, who it serves |
| `docs/CERELO_V1_REQUIREMENTS_FREEZE.md` | Frozen V1 scope |
| `docs/CERELO_USER_JOURNEYS_AND_STATE_MACHINE.md` | User journeys and state machines |
| `docs/CERELO_TECHNICAL_ARCHITECTURE.md` | Technical stack decisions |
| `docs/CERELO_DATABASE_AND_BACKEND_DOMAIN_ARCHITECTURE.md` | Database domain model |
| `docs/CERELO_SECURITY_RBAC_AND_DATA_ACCESS_ARCHITECTURE.md` | Security and authorization |

> AI coding agents must read `/docs` before modifying business logic. See `AGENTS.md`.

---

## Security Notes

> ⚠️ **CRITICAL:** Never commit `.env` files, Supabase service keys, or Firebase credentials.  
> ⚠️ The Supabase **service role key** must NEVER appear in mobile or browser client code.  
> ⚠️ All state-changing operations execute through server-side RPC functions — never via direct client database writes.

---

## Contributing

1. Create a feature branch from `main`.
2. Run `melos run analyze` and `pnpm lint && pnpm typecheck` before pushing.
3. Ensure tests pass: `melos run test` and `pnpm test`.
4. Security-sensitive changes (auth, payments, state transitions, migrations) require careful review.
5. See `AGENTS.md` for AI agent contribution rules.
