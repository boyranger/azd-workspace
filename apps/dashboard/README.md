# Dashboard Scaffold (Sprint 1)

## Run local

```bash
cd apps/dashboard
nvm use
npm install
npm run dev
```

## Environment

Copy `.env.example` to `.env.local` and set:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `SUPABASE_COOKIE_SECURE` (`true` by default, set `false` if app is served via plain HTTP)

## Auth and role checks

- Login page uses Supabase email/password auth (`/login`).
- Middleware refreshes Supabase session cookies.
- `/app/*` requires authenticated user + profile role minimal `viewer`.
- `/admin/*` requires authenticated user + profile role minimal `staff`.
- `/admin/users` requires role `owner`.

## Features implemented

1. `POST /api/admin/devices`
- role `staff+`
- create device + generate MQTT credential (returned once)

2. `POST /api/admin/devices/:id/rotate`
- role `owner` only
- rotate MQTT credential for one device

3. `PATCH /api/admin/users/:id/role`
- role `owner` only
- update role user tenant (`owner|staff|viewer`)

4. `GET /api/ingest/status`
- role `staff+`
- ingest summary (`last_5m`, `last_1h`) + health (`healthy|degraded|stale`) + latest telemetry preview

5. `GET/POST /api/admin/alerts`, `PATCH/DELETE /api/admin/alerts/:id`
- role `staff+`
- CRUD alert rule tenant (`metric`, `operator`, `threshold`, `enabled`)

6. `POST /api/admin/alerts/evaluate`
- role `staff+`
- evaluate enabled alerts against current ingest metrics and write `alert_events` (dedup 5m)

7. Logout flow
- `Logout` button on Admin/Tenant layout
- endpoint: `POST /api/auth/logout`

8. Password management
- Halaman `/app/profile` menyediakan update password untuk user login (termasuk admin/owner).

## Data binding included

- `/app`: device count, telemetry count, latest telemetry by tenant.
- `/app/devices`: tenant device list.
- `/admin`: tenant summary counters.
- `/admin/devices`: list + create/rotate actions.
- `/admin/users`: list user tenant + update role (owner only).
- `/admin/ingest`: throughput ingest + recent telemetry events.
- `/admin/alerts`: CRUD alert rules tenant.
