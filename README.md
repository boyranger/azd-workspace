# MQTT SaaS IoT/AI Workspace
codex resume 019c6bb6-cc35-7ad3-b7e3-a6495d2939bf
Repo ini sekarang difokuskan untuk backend MQTT SaaS (Azure VPS + Azure Function ingest + Supabase).

## Active Components

- `scripts/deploy_backend_vps.sh` - provision backend VPS di Azure.
- `scripts/check_backend_vps_status.sh` - cek status resource backend.
- `src/functions_mqtt_ingest/` - Azure Function ingest MQTT ke Supabase PostgreSQL.
- `apps/dashboard/` - Next.js scaffold untuk Admin Panel dan User FE.
- `supabase/migrations/20260218_sprint1_core.sql` - migration awal tabel + RLS Sprint 1.
- `docs/architecture.md` - arsitektur MVP.
- `docs/backend-vps-deploy.md` - panduan deploy backend VPS.
- `docs/planning-backend-next.md` - planning lanjutan backend.
- `docs/panel-admin-user-blueprint.md` - blueprint admin panel + user FE.
- `docs/runbook.md` - runbook operasional backend + dashboard.
- `docs/onboarding-dashboard-5min.md` - cheat-sheet onboarding user dashboard.

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

## Archived Legacy Project

Seluruh komponen project sebelumnya (zeroclaw/container-app template) dipindahkan ke:

- `archive/zeroclaw-legacy-20260218/`
- `archives/zeroclaw-legacy-20260218.tar.gz`
- `archives/zeroclaw-legacy-20260218.contents.txt`
