# MQTT SaaS IoT/AI Workspace

Repo ini sekarang difokuskan untuk backend MQTT SaaS (Azure VPS + Azure Function ingest + Supabase).

## Active Components

- `scripts/deploy_backend_vps.sh` - provision backend VPS di Azure.
- `scripts/check_backend_vps_status.sh` - cek status resource backend.
- `src/functions_mqtt_ingest/` - Azure Function ingest MQTT ke Supabase PostgreSQL.
- `worker/` - Azure worker Node.js + Prisma (runtime read/write, no migration, schema aligned via `prisma db pull` + `prisma generate`).
- `apps/dashboard/` - Next.js scaffold untuk Admin Panel dan User FE.
- `supabase/migrations/` - migration schema + RLS (Sprint 1-2).
- `docs/architecture.md` - arsitektur MVP.
- `docs/mvp-brief.md` - brief scope MVP agar fokus tidak melebar.
- `docs/backend-vps-deploy.md` - panduan deploy backend VPS.
- `docs/planning-backend-next.md` - planning lanjutan backend.
- `docs/panel-admin-user-blueprint.md` - blueprint admin panel + user FE.
- `docs/runbook.md` - runbook operasional backend + dashboard.
- `docs/onboarding-dashboard-5min.md` - cheat-sheet onboarding user dashboard.
- `docs/platform-principles.md` - prinsip arsitektur dan pembagian tanggung jawab layer.

## Dashboard Quick Start

```bash
cd apps/dashboard
npm install
npm run dev
```

Dashboard status:
- Supabase Auth login aktif (`/login`).
- Role guard aktif (`viewer/staff/owner`).
- Admin device API aktif: create (`staff+`) dan rotate credential (`owner` only).

## Worker Quick Notes

- Detail operasional worker ada di `worker/README.md`.
- Lookup ingest worker: `MqttDevice(deviceId)` -> `user.tenantId` -> insert ke `Telemetry`.
- Tidak menjalankan migration dari worker runtime; hanya `npx prisma generate`.

## Archived Legacy Project

Artefak non-aktif tersisa di:

- `archive/non-active-20260218/pivot_mqtt_saas_iot_ai.md`
- `archive/non-active-20260218/assets/`
