# Architecture: MQTT SaaS IoT/AI

## Scope

Arsitektur MVP untuk SaaS IoT/AI yang hemat budget, dengan target UMKM/SME.

## Target stack

- Frontend: Cloudflare Pages, Next.js 14 App Router, static-first.
- Backend core:
  - Azure VM Ubuntu Server 24 (`Standard_B1s`) untuk MQTT broker (Mosquitto).
  - Azure Functions (Consumption) untuk ingest, rule, dan processing.
  - Azure IoT Hub Free tier untuk device management dasar.
- Data:
  - Supabase (Auth + PostgreSQL) untuk auth, tenant, metadata, dan telemetry utama.
  - Azure Blob Storage untuk cold archive (>30 hari) bersifat opsional (fase berikutnya).
- API strategy:
  - Utama: API di Azure Functions.
  - Opsional: API terpisah hanya jika dibutuhkan (hindari biaya tetap tambahan di awal).

## Logical flow

```text
Device -> MQTT Broker (VM) -> Processor (Functions)
       -> Supabase PostgreSQL (telemetry utama)
       -> Blob (cold archive, optional)
       -> API -> Dashboard (Cloudflare Pages)
```

## Design principles

- Single-VM first: mulai dari 1 VM untuk menekan burn rate.
- Static-first frontend: minimalkan compute runtime frontend.
- Hot/cold split storage: query cepat tetap murah, data lama dipindah ke arsip.
- Scale by proof: upgrade resource hanya saat metrik bottleneck jelas.

## Current implementation snapshot (18 Februari 2026)

- MQTT broker aktif di Azure VM `Standard_B1s`.
- Azure Function `mqtt_ingest` ingest langsung dari MQTT ke Supabase PostgreSQL.
- Tabel telemetry aktif: `public.telemetry`.
- Blob archive saat ini dinonaktifkan; ingest utama hanya ke Supabase PostgreSQL.

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
  - pecah worker ingest jika throughput naik,
  - evaluasi API gateway bila policy/rate-limit makin kompleks.

## Risks and mitigations

- Single point of failure di VM.
  - Mitigasi: backup harian, restore drill, snapshot terjadwal.
- Lonjakan biaya AI API.
  - Mitigasi: token cap per tenant, model routing, cache hasil.
- Egress naik saat data streaming besar.
  - Mitigasi: kompres payload, batching, retention policy ketat.
