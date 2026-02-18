# Costing: MQTT SaaS IoT/AI

## Assumptions

- Region: East Asia.
- Date baseline: 17 Februari 2026.
- Currency: USD.
- VM pricing di bawah adalah compute-only (belum disk, IP, egress).

## VM compute pricing

| VM | USD/jam | USD/hari | USD/bulan (30 hari) |
|---|---:|---:|---:|
| Standard_B1s | 0.0146 | 0.3504 | 10.5120 |
| Standard_B2s | 0.0584 | 1.4016 | 42.0480 |

## Budget scenarios

### Month 1-13 (lean MVP/pilot)

- VM `B1s` compute: `~$10.51/bulan`.
- + disk/IP/egress dasar: total realistis `~$13-$18/bulan`.
- Optimasi:
  - Supabase Free,
  - Azure Functions Consumption (usage rendah),
  - IoT Hub Free tier.

### Month 14+ (scale awal)

- VM `B2s` compute: `~$42.05/bulan`.
- Supabase Pro (saat free limit lewat): `~$25/bulan`.
- + disk/IP/egress tambahan: `~$8-$18/bulan`.
- Total realistis:
  - tanpa layanan API berbiaya tetap tambahan: `~$75-$95/bulan`.
  - dengan layanan API berbayar tambahan: `~$95-$115/bulan`.

## Cost components to track

- VM compute.
- Managed disk.
- Public IP.
- Network egress.
- Domain.
- AI API token usage.

## Guardrails

- Budget alert Azure aktif dari hari pertama.
- Quota per tenant untuk message dan token.
- Retention policy:
  - telemetry utama di Supabase PostgreSQL,
  - cold archive ke Blob hanya jika volume sudah menuntut.
- Scale trigger:
  - CPU VM konsisten tinggi,
  - queue lag bertambah,
  - p95 latency naik,
  - atau error rate meningkat.

## Notes

- Nilai di dokumen ini bukan invoice final, tapi baseline perencanaan.
- Perubahan region/SKU akan mengubah harga.
- Status implementasi per 18 Februari 2026: ingest aktif langsung ke Supabase PostgreSQL; Blob archive sedang dinonaktifkan.
