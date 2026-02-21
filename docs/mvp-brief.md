# MVP Brief: IoT SaaS (Focused Scope)

## Tujuan MVP

- Platform menerima data sensor via MQTT.
- Data tersimpan per tenant dengan isolasi yang jelas.
- User login dan mengelola device/data sesuai role.

## In-Scope (Wajib)

- Multi-tenant dasar: `tenants`, `profiles`, `devices`, `telemetry`.
- Auth user: Supabase Auth (email/password).
- Role akses: `owner`, `staff`, `viewer`.
- Ingest data: MQTT broker -> Azure Function `mqtt_ingest` -> Supabase PostgreSQL.
- Dashboard:
  - `/app`: ringkasan tenant + data terbaru.
  - `/admin/devices`: create/rotate credential device.
  - `/admin/users`: kelola role user tenant.
  - `/admin/ingest`: health + throughput.
  - `/admin/alerts`: CRUD rule + evaluate manual.
- RLS aktif di tabel tenant-scoped.

## Out-of-Scope (Tunda)

- Billing/subscription payment.
- OTA/firmware management.
- AI analytics kompleks.
- Integrasi enterprise besar.
- Multi-region HA kompleks.
- UI realtime advanced di luar kebutuhan MVP.

## Data Minimum

- `tenants`: identitas customer.
- `profiles`: mapping auth user -> tenant + role.
- `devices`: identitas device + credential MQTT.
- `telemetry`: payload sensor berbasis waktu.
- `alerts`, `alert_events`: rule dan event alert dasar.

## Alur Utama

1. Device publish ke MQTT TLS `8883`.
2. Function ingest collect batch, retry+dedup, insert ke `telemetry`.
3. User login dashboard; data dibatasi per tenant via RLS.
4. Admin tenant kelola device/user dan monitor ingest.

## Definition of Done MVP

- Tenant A tidak bisa baca data Tenant B.
- Device berhasil kirim telemetry dan tampil di dashboard tenant.
- Owner bisa create user dan set role.
- Staff/owner bisa create device credential.
- Ingest stabil dengan retry/dedup aktif.
- Alert rule bisa dibuat dan menghasilkan `alert_events`.

## KPI MVP (2-4 Minggu Awal)

- Success ingest rate >= 99%.
- Duplicate telemetry turun signifikan (dedup aktif).
- Onboarding tenant baru <= 10 menit.
- Tidak ada akses cross-tenant.

## Prioritas Berikutnya

1. Stabilkan scheduler `mqtt_ingest` (monitor run per menit).
2. Sinkronisasi credential dashboard -> Mosquitto realtime.
3. Automasi evaluate alerts (timer), bukan manual saja.
4. Tambah notifikasi alert (email/webhook) minimal satu channel.
