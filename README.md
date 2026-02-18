# MQTT SaaS IoT/AI Workspace

Repo ini sekarang difokuskan untuk backend MQTT SaaS (Azure VPS + Azure Function ingest + Supabase).

## Active Components

- `scripts/deploy_backend_vps.sh` - provision backend VPS di Azure.
- `scripts/check_backend_vps_status.sh` - cek status resource backend.
- `src/functions_mqtt_ingest/` - Azure Function ingest MQTT ke Supabase PostgreSQL.
- `docs/architecture.md` - arsitektur MVP.
- `docs/backend-vps-deploy.md` - panduan deploy backend VPS.
- `docs/planning-backend-next.md` - planning lanjutan backend.
- `docs/panel-admin-user-blueprint.md` - blueprint admin panel + user FE.

## Archived Legacy Project

Seluruh komponen project sebelumnya (zeroclaw/container-app template) dipindahkan ke:

- `archive/zeroclaw-legacy-20260218/`
- `archives/zeroclaw-legacy-20260218.tar.gz`
- `archives/zeroclaw-legacy-20260218.contents.txt`

