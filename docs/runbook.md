# Runbook: Deploy and Operate MQTT SaaS MVP

## Objective

Menjalankan MVP MQTT SaaS dengan stack:
- Azure VM Ubuntu 24 + Mosquitto
- Azure Functions
- Supabase
- Next.js dashboard

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
- [ ] baca dan setujui `docs/platform-principles.md`

## Policy Guardrail (Wajib)

- Source of truth data hanya Supabase.
- Hanya satu `DATABASE_URL` aktif per environment.
- Azure runtime tidak boleh menjalankan migration.
- Di Azure hanya boleh `npx prisma generate`.
- `prisma migrate` / `prisma db push` hanya dilakukan dari jalur schema owner, bukan dari Azure worker/runtime.

## 2) Provision core infra (Azure)

Checklist:
- [ ] Resource Group dibuat
- [ ] VM Ubuntu 24 (`B1s`) dibuat
- [ ] NSG minimum port:
  - `22` (batasi IP admin)
  - `8883` (MQTT TLS)
- [ ] Public IP terpasang
- [ ] Function App (Consumption) dibuat

### Cara masuk Azure VM via SSH

0. Verifikasi subscription aktif dan resource:
```bash
az account show --query "{name:name,id:id}" -o table
az vm list -d --query "[].{rg:resourceGroup,name:name,ip:publicIps,power:powerState}" -o table
```
1. Ambil public IP VM:
```bash
az vm show -g MYLOWCOSTVM_GROUP -n zeroclaw-b1s -d --query publicIps -o tsv
```
2. Login SSH:
```bash
ssh far-azd@<VM_PUBLIC_IP>
```
3. Jika pakai key non-default:
```bash
ssh -i ~/.ssh/<PRIVATE_KEY_FILE> far-azd@<VM_PUBLIC_IP>
```

Catatan:
- Pastikan NSG rule `allow-ssh` hanya buka port `22` untuk IP admin (`/32`), bukan `*`.
- Panduan lengkap hardening login tanpa password ada di `docs/ssh-key-login.md`.

## 3) Configure VM

Checklist:
- [ ] update system packages
- [ ] install Mosquitto + clients
- [ ] enable and start service
- [ ] set auth (password file/ACL)
- [ ] aktifkan TLS untuk `8883`

Hardening minimum:
- [ ] disable root SSH login
- [ ] prefer SSH key auth
- [ ] fail2ban/ufw sesuai kebutuhan
- [ ] log rotation aktif

### Broker hardening transitional (aktif)

Status per 21 Februari 2026:
- ACL global `user admin` + `topic readwrite #` sudah dihapus.
- Model sementara: credential per-device + ACL write per-device.
- Contoh user device yang sudah diterapkan: `device-123`.

Langkah standar untuk tambah device baru:
```bash
sudo mosquitto_passwd /etc/mosquitto/passwd <device-id>
```

Tambahkan ACL device ke `/etc/mosquitto/acl`:
```conf
user <device-id>
topic write devices/<device-id>/#
topic write device/<device-id>/#
```

Restart broker:
```bash
sudo systemctl restart mosquitto
sudo systemctl is-active mosquitto
```

Catatan permission file Mosquitto:
- Gunakan owner/group: `root:mosquitto`
- Mode file: `640`
- Jika diubah ke `root:root`, service bisa gagal start (exit status 13 pada environment saat ini).

## 4) Data and app setup

Supabase:
- [ ] auth schema siap
- [ ] table tenant/device/telemetry siap
- [ ] RLS policy sesuai tenant

Functions:
- [ ] function ingest dari MQTT bridge/event -> Supabase PostgreSQL
- [ ] function ingest reliability (retry/dedup/logging) terpasang

Azure worker (Node + Prisma, jika dipakai):
- [ ] jalankan `npm install`
- [ ] jalankan `npx prisma generate`
- [ ] jangan jalankan `npx prisma migrate` di VM/runtime
- [ ] pastikan `PrismaClient` singleton (bukan per message)
- [ ] pastikan worker dijalankan dengan env file (`npm run start` -> `node --env-file=.env dist/worker.js`)
- [ ] pastikan DNS + outbound `:5432` ke host Supabase tersedia

Dashboard:
- [ ] project dashboard terdeploy
- [ ] env var endpoint API terpasang
- [ ] custom domain + TLS aktif (jika sudah ada domain)

## 5) Go-live checklist

- [ ] publish telemetry dari test device berhasil
- [ ] data realtime tampil di dashboard
- [ ] alert rule terkirim
- [ ] backup harian database aktif
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
- kompres payload
- batasi field telemetry non-kritis

## 8) Current state (18 Februari 2026)

- Backend live di Azure VM + Function App.
- Ingest aktif: MQTT -> Azure Function `mqtt_ingest` -> Supabase PostgreSQL (`public.telemetry`).
- Blob archive tidak digunakan pada fase aktif saat ini.
- Broker hardening phase 1 aktif: ACL per-device dan credential per-device (tanpa ACL global).

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

5. Worker error `Can't reach database server`
- Cek DNS host Supabase:
```bash
getent hosts aws-1-ap-southeast-1.pooler.supabase.com
```
- Cek TCP koneksi:
```bash
timeout 5 bash -lc '</dev/tcp/aws-1-ap-southeast-1.pooler.supabase.com/5432' && echo OK
```
- Jika gagal: perbaiki rule egress NSG/firewall dan DNS resolver pada runtime worker.

6. Broker gagal start setelah update ACL/passwd (`Unable to open pwfile`, exit status 13)
- Gejala:
  - `systemctl status mosquitto` menunjukkan `status=13`
  - log berisi `Error: Unable to open pwfile "/etc/mosquitto/passwd"`
- Recovery:
```bash
sudo chown root:mosquitto /etc/mosquitto/passwd /etc/mosquitto/acl
sudo chmod 640 /etc/mosquitto/passwd /etc/mosquitto/acl
sudo systemctl reset-failed mosquitto
sudo systemctl restart mosquitto
sudo systemctl is-active mosquitto
```

7. Test publish lokal TLS gagal (`Unable to connect (A TLS error occurred.)`)
- Penyebab umum:
  - mismatch hostname/certificate saat konek ke `127.0.0.1:8883`
  - parameter TLS client tidak cocok.
- Opsi aman untuk verifikasi cepat publish:
```bash
sudo mosquitto_pub -h 127.0.0.1 -p 1883 -u <device-id> -P '<password>' -t devices/<device-id>/telemetry -m '{"ping":"ok"}'
```
- Jika wajib test TLS, pakai hostname yang sesuai cert CN/SAN dan CA yang benar.
