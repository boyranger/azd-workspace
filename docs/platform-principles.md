# Platform Principles (Locked)

Prinsip ini wajib jadi baseline operasional untuk environment aktif.

## 1) Single Source of Truth

- Hanya 1 Supabase project (production source of truth).
- Hanya 1 `DATABASE_URL` aktif per environment.
- Hanya 1 schema owner untuk perubahan struktur schema.
- Azure runtime tidak boleh menjalankan migration schema.

Aturan Azure untuk Prisma:
- `npx prisma generate` boleh.
- `prisma migrate`, `prisma db push`, dan DDL migration dari Azure tidak boleh.

Recommended setup di Azure VM:
- `npm install`
- `npx prisma generate`
- Jangan jalankan `npx prisma migrate`.

Untuk `package.json` Azure worker:
```json
{
  "scripts": {
    "generate": "prisma generate",
    "start": "node --env-file=.env dist/worker.js"
  }
}
```
Tidak boleh ada script migration di runtime worker.

## 2) Layer Responsibility

### Supabase (Data Layer)

Tanggung jawab:
- Data persistence.
- `pgvector` / vector store.
- Multi-tenant tables.
- Audit data.

Bukan tanggung jawab:
- Logic bisnis aplikasi.

### Azure VM / Worker (Transport + Edge Worker)

Tanggung jawab:
- Mosquitto broker.
- MQTT ingest worker.
- Forward event.
- Lightweight processing.
- Prisma read/write only (tanpa migration).

Peran layer ini: transport dan edge worker, bukan schema owner.

## 3) Network and Prisma Client

- Karena Supabase dipakai lintas layer, jaga batas connection pool.
- Jangan membuat `PrismaClient` berulang per message/event.
- Wajib gunakan singleton pattern untuk lifecycle process worker.
- Runtime wajib punya DNS resolver + outbound ke host Supabase pada port `5432`.

Contoh minimal:
```ts
import { PrismaClient } from "@prisma/client";

export const prisma =
  globalThis.__prisma ??
  new PrismaClient({
    datasources: {
      db: {
        url: process.env.DATABASE_URL
      }
    }
  });

if (process.env.NODE_ENV !== "production") {
  globalThis.__prisma = prisma;
}
```
