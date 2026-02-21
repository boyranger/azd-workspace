# Pivot MQTT SaaS IoT/AI

Dokumen ini sekarang jadi index ringkas. Detail dipisah ke dokumen berikut:

- Arsitektur: `docs/architecture.md`
- Costing: `docs/costing.md`
- Runbook implementasi: `docs/runbook.md`

## Snapshot keputusan

- Frontend: Cloudflare Pages + Next.js 14 (static-first).
- Data/Auth: Supabase Free untuk hot data + auth, Blob untuk cold archive.
- Backend: Azure VM Ubuntu 24 (Mosquitto), Azure Functions, Azure IoT Hub Free.
- Strategy biaya: mulai di `B1s`, scale ke `B2s` hanya saat bottleneck terbukti.

## Catatan

Semua angka biaya di dokumen `docs/costing.md` memakai acuan East Asia per 17 Februari 2026.
