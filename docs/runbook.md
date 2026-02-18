# Runbook: Deploy and Operate MQTT SaaS MVP

## Objective

Menjalankan MVP MQTT SaaS dengan stack:
- Azure VM Ubuntu 24 + Mosquitto
- Azure Functions
- Supabase
- Cloudflare Pages
- Azure Blob archive (opsional fase lanjut)

## 1) Preflight

- Pastikan subscription Azure aktif.
- Pastikan domain sudah tersedia (opsional untuk fase awal).
- Siapkan secret management:
  - MQTT credentials
  - Supabase keys
  - AI provider keys
  - JWT/app secrets

Checklist:
- [ ] `az login` sukses
- [ ] subscription aktif sudah dipilih
- [ ] naming convention resource disepakati

## 2) Provision core infra (Azure)

Checklist:
- [ ] Resource Group dibuat
- [ ] VM Ubuntu 24 (`B1s`) dibuat
- [ ] NSG minimum port:
  - `22` (batasi IP admin)
  - `443`
  - `1883` (jika pakai plain MQTT)
  - `8883` (MQTT TLS)
  - `9001` (MQTT WebSocket, jika dipakai)
- [ ] Public IP terpasang
- [ ] Azure Blob container untuk archive dibuat (opsional)
- [ ] Function App (Consumption) dibuat
- [ ] IoT Hub Free dibuat (jika dipakai)

## 3) Configure VM

Checklist:
- [ ] update system packages
- [ ] install Mosquitto + clients
- [ ] enable and start service
- [ ] set auth (password file/ACL)
- [ ] aktifkan TLS untuk `8883`
- [ ] aktifkan WebSocket `9001` jika dashboard butuh
- [ ] setup reverse proxy bila ada API/UI di VM

Hardening minimum:
- [ ] disable root SSH login
- [ ] prefer SSH key auth
- [ ] fail2ban/ufw sesuai kebutuhan
- [ ] log rotation aktif

## 4) Data and app setup

Supabase:
- [ ] auth schema siap
- [ ] table tenant/device/telemetry siap
- [ ] RLS policy sesuai tenant

Functions:
- [ ] function ingest dari MQTT bridge/event -> Supabase PostgreSQL
- [ ] function alert/rule engine
- [ ] function archive ke Blob (opsional jika retention policy perlu)

Cloudflare Pages:
- [ ] project dashboard terdeploy
- [ ] env var endpoint API terpasang
- [ ] custom domain + TLS aktif (jika sudah ada domain)

## 5) Go-live checklist

- [ ] publish telemetry dari test device berhasil
- [ ] data realtime tampil di dashboard
- [ ] alert rule terkirim
- [ ] backup harian database aktif
- [ ] archive >30 hari berjalan (opsional sesuai fase)
- [ ] uptime monitoring aktif
- [ ] cost dashboard + budget alert aktif

## 6) Operational cadence

Daily:
- cek uptime broker/API
- cek error log dan failed jobs
- cek burn rate biaya harian

Weekly:
- review top tenant usage
- review AI token spend
- test restore sample backup

Monthly:
- review kapasitas VM
- evaluasi upgrade `B1s` -> `B2s` (jika metrik bottleneck)
- review pricing plan tenant

## 7) Incident playbooks

Broker down:
- restart service
- validasi disk penuh/log flood
- failover sementara (maintenance mode)

Cost spike:
- cek egress dan token usage
- aktifkan rate limit tenant
- turunkan retention sementara

Data growth spike:
- percepat archive policy (jika Blob archive sudah diaktifkan)
- kompres payload
- batasi field telemetry non-kritis

## 8) Current state (18 Februari 2026)

- Backend live di Azure VM + Function App.
- Ingest aktif: MQTT -> Azure Function `mqtt_ingest` -> Supabase PostgreSQL (`public.telemetry`).
- Blob archive saat ini dinonaktifkan (container `archive` dihapus).

## 9) Dashboard operations (Admin + User FE)

Lokasi dashboard:
- `apps/dashboard`
- `docs/onboarding-dashboard-5min.md` (onboarding user baru)

### A. Local run

```bash
cd apps/dashboard
npm install
npm run dev
```

Wajib env di `apps/dashboard/.env.local`:
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`

### B. Auth flow

- Login melalui `/login` (Supabase email/password).
- Middleware menjaga session untuk route:
  - `/app/*` (minimal role `viewer`)
  - `/admin/*` (minimal role `staff`)
- Role dibaca dari tabel `public.profiles`.

### C. Seed minimal user-role (manual SQL)

1. Buat user di Supabase Auth (Dashboard Supabase).
2. Pastikan ada tenant:
```sql
insert into public.tenants (name) values ('Tenant Demo') returning id;
```
3. Mapping user auth ke profile:
```sql
insert into public.profiles (id, tenant_id, role, full_name)
values ('<AUTH_USER_UUID>', '<TENANT_UUID>', 'owner', 'Admin Demo');
```

### D. API admin yang aktif

- `POST /api/admin/devices`:
  - role `staff+`
  - create device + generate credential MQTT (ditampilkan sekali).
- `POST /api/admin/devices/:id/rotate`:
  - role `owner` only
  - rotate credential device.

### E. Troubleshooting cepat

1. Error `Missing NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_ANON_KEY`
- Cek `apps/dashboard/.env.local` sudah terisi.
- Restart dev server setelah ubah env.

2. Error `cookieStore.get is not a function`
- Pastikan pakai versi terbaru kode helper Supabase server (`apps/dashboard/src/lib/supabase/server.ts`) yang sudah async cookie store.
- Restart server setelah pull/update.

3. Login berhasil tapi redirect ke `/unauthorized`
- Cek row user di `public.profiles` ada.
- Cek `tenant_id` valid dan `role` sesuai (`owner|staff|viewer`).

4. Admin lupa password
- Reset di Supabase Auth dashboard, atau
- login sebagai user tersebut lalu ubah password di `/app/profile`.
