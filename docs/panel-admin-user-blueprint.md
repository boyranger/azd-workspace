# Blueprint Panel Admin dan User FE

## 1. Target Arsitektur Aplikasi

Gunakan satu codebase Next.js (App Router), dipisah jadi dua area:

- `app/admin/*` untuk internal operation panel.
- `app/app/*` untuk dashboard user tenant.

Alasan:
- Reuse auth, komponen UI, dan util API.
- Isolasi permission cukup di middleware + server action guard.
- Deploy tetap sederhana (single frontend project).

## 2. Struktur Folder (Next.js 14)

```text
src/
  app/
    (public)/
      login/page.tsx
      unauthorized/page.tsx

    admin/
      layout.tsx
      page.tsx                     # admin overview
      tenants/page.tsx             # list/manage tenant
      tenants/[tenantId]/page.tsx
      users/page.tsx               # manage role user
      devices/page.tsx             # global device ops
      ingest/page.tsx              # monitoring ingest/errors
      costs/page.tsx               # usage/cost summary

    app/
      layout.tsx
      page.tsx                     # user dashboard
      devices/page.tsx
      devices/[deviceId]/page.tsx
      alerts/page.tsx
      profile/page.tsx

    api/
      admin/
        tenants/route.ts
        users/route.ts
        devices/route.ts
      ingest/
        status/route.ts
      telemetry/
        latest/route.ts
        range/route.ts

  components/
    ui/
    charts/
    tables/
    forms/

  lib/
    auth/
      session.ts
      roles.ts
      guards.ts
    supabase/
      client.ts
      server.ts
    api/
      admin.ts
      telemetry.ts
    validation/
      tenant.ts
      device.ts
      alert.ts

  middleware.ts
```

## 3. Model Data Supabase (MVP)

### 3.1 Tabel Inti

1. `tenants`
- `id uuid pk default gen_random_uuid()`
- `name text not null`
- `status text not null default 'active'` (`active|suspended`)
- `plan text not null default 'starter'`
- `created_at timestamptz default now()`

2. `profiles`
- `id uuid pk` (refer `auth.users.id`)
- `tenant_id uuid not null references tenants(id)`
- `full_name text`
- `role text not null` (`owner|staff|viewer`)
- `created_at timestamptz default now()`

3. `devices`
- `id uuid pk default gen_random_uuid()`
- `tenant_id uuid not null references tenants(id)`
- `device_code text not null unique`
- `name text not null`
- `status text not null default 'active'` (`active|disabled`)
- `mqtt_username text not null`
- `mqtt_password_hash text not null`
- `last_seen_at timestamptz`
- `created_at timestamptz default now()`

4. `telemetry`
- `id bigserial pk`
- `tenant_id uuid not null references tenants(id)`
- `device_id uuid references devices(id)`
- `topic text not null`
- `payload_text text not null`
- `payload_json jsonb`
- `qos int not null default 0`
- `retain boolean not null default false`
- `received_at timestamptz not null`
- `ingested_at timestamptz not null default now()`

5. `alerts`
- `id uuid pk default gen_random_uuid()`
- `tenant_id uuid not null references tenants(id)`
- `name text not null`
- `metric text not null`
- `operator text not null`
- `threshold numeric not null`
- `enabled boolean not null default true`
- `created_at timestamptz default now()`

6. `alert_events`
- `id bigserial pk`
- `alert_id uuid not null references alerts(id)`
- `tenant_id uuid not null references tenants(id)`
- `device_id uuid references devices(id)`
- `message text not null`
- `triggered_at timestamptz not null default now()`

### 3.2 Index Minimum

- `telemetry(tenant_id, received_at desc)`
- `telemetry(device_id, received_at desc)`
- `devices(tenant_id, status)`
- `profiles(tenant_id, role)`

## 4. RLS dan Permission Matrix

## 4.1 RLS Rule Baseline

- Semua tabel tenant-scoped wajib `tenant_id`.
- User hanya bisa akses row dengan `tenant_id = profile.tenant_id`.
- `viewer`: read-only.
- `staff`: read + update device/alert terbatas.
- `owner`: full akses tenant (termasuk user role management).
- Super admin platform (internal) via backend service role only (bukan dari browser).

## 4.2 Matrix Akses

| Resource | owner | staff | viewer |
|---|---|---|---|
| Tenants (own) | R/W | R | R |
| Profiles (own tenant) | R/W | R | R |
| Devices (own tenant) | R/W | R/W | R |
| Telemetry (own tenant) | R | R | R |
| Alerts (own tenant) | R/W | R/W | R |
| Alert events (own tenant) | R | R | R |
| Cross-tenant data | No | No | No |

## 5. Route Map

### 5.1 Public

- `/login`
- `/unauthorized`

### 5.2 Admin Panel

- `/admin`
- `/admin/tenants`
- `/admin/tenants/[tenantId]`
- `/admin/users`
- `/admin/devices`
- `/admin/ingest`
- `/admin/costs`

Guard:
- minimal role: `staff`.
- route sensitif (`/admin/users`, `/admin/tenants`) role `owner`.

### 5.3 User FE

- `/app`
- `/app/devices`
- `/app/devices/[deviceId]`
- `/app/alerts`
- `/app/profile`

Guard:
- semua role tenant (`owner|staff|viewer`).

## 6. API Contract Ringkas

1. `GET /api/telemetry/latest?deviceId=...`
- Return latest N telemetry by device.

2. `GET /api/telemetry/range?deviceId=...&from=...&to=...`
- Return telemetry in range.

3. `POST /api/admin/devices`
- Create device + generate mqtt credential (hash only stored).

4. `POST /api/admin/devices/:id/rotate`
- Rotate device credential.

5. `POST /api/admin/users/:id/role`
- Update role (owner only).

6. `GET /api/ingest/status`
- Return ingest health summary (last run, count/minute, error count).

## 7. Implementasi Bertahap

### Sprint 1 (Foundation)

1. Setup auth session + role guard middleware.
2. Buat tabel `tenants/profiles/devices/telemetry` + index.
3. Implement route `/app`, `/app/devices`, `/admin`, `/admin/devices`.

### Sprint 2 (Ops)

1. Tambah `/admin/ingest`, `/admin/users`.
2. Tambah alert CRUD (`alerts`, `alert_events`).
3. Tambah API `ingest/status`.

### Sprint 3 (Polish)

1. Cost/usage view per tenant.
2. Export telemetry CSV.
3. Audit trail untuk aksi admin sensitif.

## 8. Checklist Siap Mulai Coding

- [ ] Putuskan provider auth final (Supabase Auth).
- [ ] Konfirmasi naming final tabel (`telemetry` sudah dipakai ingest saat ini).
- [ ] Buat migration SQL awal + RLS.
- [ ] Scaffold route kosong sesuai struktur folder.
- [ ] Implement middleware role guard.
- [ ] Implement minimal 2 halaman: `/admin/devices` dan `/app/devices`.
