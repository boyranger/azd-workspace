# Azure Worker (Prisma)

Worker ini mengikuti policy:
- Tidak menjalankan migration di Azure runtime.
- Hanya generate Prisma Client dari schema existing.
- Menggunakan singleton `PrismaClient`.
- Read-only untuk device mapping.
- Write-only untuk telemetry.
- `tenantId` disimpan langsung pada row telemetry.

## Lookup Flow (Aktif)

Saat ingest event:
- lookup device berdasarkan `event.deviceId` ke tabel `MqttDevice`
- select field minimal: `deviceId`, `connected`, dan `user.tenantId`
- ambil `tenantId` dari `device.user.tenantId`
- insert ke `telemetry` dengan `tenantId` tersebut

Jika device tidak ditemukan atau `connected=false`, event di-skip.

## Setup

```bash
cd worker
npm install
cp .env.example .env
# edit DATABASE_URL di file .env
npx prisma generate
npm run build
npm run start
```

## Env wajib

- `DATABASE_URL`

## Env opsional untuk test ingest

- `TEST_DEVICE_ID`
- `TEST_PAYLOAD_JSON`

## Troubleshooting Koneksi DB

Jika muncul `Can't reach database server`:

```bash
getent hosts aws-1-ap-southeast-1.pooler.supabase.com
timeout 5 bash -lc '</dev/tcp/aws-1-ap-southeast-1.pooler.supabase.com/5432' && echo OK
```

Jika gagal:
- pastikan DNS resolver bisa dipakai dari runtime
- pastikan outbound ke host Supabase port `5432` diizinkan (NSG/firewall/egress policy)

## Scripts

- `npm run generate` -> `prisma generate`
- `npm run build` -> compile TypeScript ke `dist/`
- `npm run start` -> jalankan `node --env-file=.env dist/worker.js`
