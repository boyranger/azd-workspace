# Planning Lanjutan Backend (Azure VPS + Supabase)

## Tujuan

Dokumen ini jadi baseline plan untuk sesi lanjutan setelah status saat ini:
- Backend VPS Azure sudah running.
- MQTT broker (Mosquitto) aktif.
- Azure Function `mqtt_ingest` sudah ingest data MQTT ke Supabase PostgreSQL.

## Snapshot Status Saat Ini

- Resource Group: `MyLowCostVM_group`
- VM: `zeroclaw-b1s`
- Public IP: `20.24.82.139`
- MQTT:
  - TLS endpoint: `20.24.82.139:8883`
  - Plain MQTT local test: `1883`
- Function App: `func-zeroclaw-b1s-dd58ef`
- Database ingest target: Supabase PostgreSQL via `EXTERNAL_DATABASE_CONNECTION_STRING`
- Tabel ingest: `public.telemetry`

## Scope Lanjutan (Belum Dikerjakan)

1. Security hardening network dan VM.
2. Hardening MQTT auth/TLS.
3. Hardening aplikasi ingest (resilience + observability).
4. Operasional runbook dan rollback plan.

## Prioritas Eksekusi

### Phase 1 - Critical Hardening

1. Batasi SSH inbound NSG ke IP admin tetap (`/32`).
2. Tutup akses publik port `1883` (plain MQTT).
3. Pastikan hanya `8883` untuk device publik.
4. Rotate kredensial MQTT default (`admin`) ke credential baru per environment.
5. Simpan secret hanya di app settings/secret manager, bukan di script output.

Definition of done:
- NSG rule `allow-ssh` source bukan `*`.
- Tidak ada inbound publik ke port `1883`.
- Device masih bisa connect via `8883`.

### Phase 2 - TLS/Identity Improvement

1. Ganti sertifikat self-signed dengan cert CA valid.
2. Terapkan ACL topic per tenant/device (minimal prefix-based ACL).
3. Rencana rotasi cert + password berkala.

Definition of done:
- Koneksi MQTT TLS tervalidasi tanpa `--insecure`.
- Akses topic lintas tenant ditolak oleh ACL.

### Phase 3 - Function Ingest Reliability

1. Tambahkan dedup key/idempotency sederhana (mis. hash topic+payload+timestamp bucket).
2. Tambahkan retry policy untuk koneksi DB.
3. Tambahkan batch size cap dan timeout guard.
4. Tambahkan structured log yang mudah di-query.

Definition of done:
- Tidak ada spike duplicate insert pada uji beban ringan.
- Error transient DB tidak langsung drop data batch.

### Phase 4 - Observability & Ops

1. Setup alert minimum:
   - Function error rate.
   - VM CPU/memory threshold.
   - Kegagalan koneksi MQTT.
2. Buat dashboard metrik dasar (ingest count/minute, error count).
3. Tambahkan runbook incident singkat (broker down, DB timeout, cost spike).

Definition of done:
- Ada alert yang benar-benar trigger saat skenario test failure.
- On-call checklist dapat dipakai tanpa tribal knowledge.

## Rencana Perintah (Saat Lanjut Eksekusi)

1. Update NSG rule SSH:
```bash
az network nsg rule update -g MyLowCostVM_group --nsg-name zeroclaw-b1s-nsg -n allow-ssh --source-address-prefixes <ADMIN_IP>/32
```

2. Hapus rule MQTT plain publik (jika ada):
```bash
az network nsg rule delete -g MyLowCostVM_group --nsg-name zeroclaw-b1s-nsg -n allow-mqtt-plain
```

3. Verifikasi rule:
```bash
az network nsg rule list -g MyLowCostVM_group --nsg-name zeroclaw-b1s-nsg -o table
```

4. Rotate MQTT password + update Function App setting `MQTT_BROKER_PASSWORD`.

5. Uji regresi:
- publish MQTT ke 8883
- invoke `mqtt_ingest`
- cek row baru di `public.telemetry`

## Risiko yang Perlu Dijaga

1. Salah update NSG bisa lock-out SSH admin.
2. Rotasi password tanpa update Function App akan putus ingest.
3. Perubahan cert TLS bisa memutus device lama yang masih trust self-signed.

## Catatan Rollback Singkat

1. Jika ingest gagal setelah rotate password:
- rollback `MQTT_BROKER_PASSWORD` di Function App ke nilai sebelumnya.
2. Jika SSH terkunci:
- gunakan `az vm run-command invoke` untuk recovery rule/sshd.
3. Jika device gagal TLS setelah cert update:
- restore cert lama sementara dan jadwalkan cutover bertahap.

## Checklist Sesi Berikutnya

- [ ] Konfirmasi IP admin yang akan di-allow untuk SSH.
- [ ] Eksekusi hardening Phase 1 penuh.
- [ ] Validasi E2E setelah hardening.
- [ ] Commit perubahan script/doc jika diperlukan.
