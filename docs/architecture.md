# Architecture: MQTT SaaS IoT/AI

## Scope

Arsitektur MVP untuk SaaS IoT/AI yang hemat budget, dengan target UMKM/SME.

## Target stack

- Frontend: Next.js App Router (`apps/dashboard`).
- Backend core:
  - Azure VM Ubuntu Server 24 (`Standard_B1s`) untuk MQTT broker (Mosquitto).
  - Azure Functions (Consumption) untuk ingest MQTT.
- Data:
  - Supabase (Auth + PostgreSQL) untuk auth, tenant, metadata, telemetry, dan alert/event.
- API strategy:
  - Dashboard API route di Next.js untuk admin/user operations.
  - Function App fokus untuk ingest pipeline.

## Logical flow

```text
Device -> MQTT Broker (VM) -> Azure Function mqtt_ingest
       -> Supabase PostgreSQL (telemetry utama)
       -> Dashboard API/UI (Next.js)
```

## Design principles

- Single-VM first: mulai dari 1 VM untuk menekan burn rate.
- Single frontend app: admin panel + user FE di satu codebase.
- Scale by proof: upgrade resource hanya saat metrik bottleneck jelas.

## Current implementation snapshot (18 Februari 2026)

- MQTT broker aktif di Azure VM `Standard_B1s`.
- Azure Function `mqtt_ingest` ingest langsung dari MQTT ke Supabase PostgreSQL.
- Tabel telemetry aktif: `public.telemetry`.
- Fitur dashboard aktif: `/admin/devices`, `/admin/users`, `/admin/ingest`, `/admin/alerts`.

## Multi-tenant baseline

- Tenant identity per customer (tenant_id).
- Device identity per tenant (device_id + key).
- Partition key data berbasis tenant dan waktu.
- RBAC minimal: owner, staff, viewer.

## Scale path

- Phase A: MVP 1 VM (`B1s`) + free/consumption services.
- Phase B: pilot 5-20 tenant, hardening auth dan observability.
- Phase C: scale:
  - upgrade VM ke `B2s` saat CPU/RAM bottleneck,
  - pecah worker ingest jika throughput naik.

## Risks and mitigations

- Single point of failure di VM.
  - Mitigasi: backup harian, restore drill, snapshot terjadwal.
- Lonjakan biaya AI API.
  - Mitigasi: token cap per tenant, model routing, cache hasil.
- Egress naik saat data streaming besar.
  - Mitigasi: kompres payload, batching, retention policy ketat.
