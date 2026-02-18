# Onboarding Dashboard 5 Menit

Panduan cepat untuk menambahkan user baru sampai bisa login ke dashboard.

## 0) Prasyarat

- Dashboard sudah jalan (`apps/dashboard`).
- Kamu punya akses Supabase SQL Editor.
- Kamu tahu role user yang akan diberikan: `owner` / `staff` / `viewer`.

## 1) Buat user di Supabase Auth

Di Supabase Dashboard:
- `Authentication` -> `Users` -> `Add user`
- Isi email + password sementara.

Simpan `user_id` (UUID) user yang baru dibuat.

## 2) Buat tenant (jika belum ada)

Jalankan di SQL Editor:

```sql
insert into public.tenants (name)
values ('Tenant Demo')
returning id;
```

Simpan `tenant_id` hasil query.

Jika tenant sudah ada, ambil `id`-nya:

```sql
select id, name from public.tenants order by created_at desc;
```

## 3) Mapping user ke profile + role

```sql
insert into public.profiles (id, tenant_id, role, full_name)
values ('<AUTH_USER_UUID>', '<TENANT_UUID>', 'staff', 'Nama User');
```

Contoh role:
- `owner`: full akses tenant + rotate credential
- `staff`: akses admin operasi device
- `viewer`: read-only dashboard tenant

## 4) Login ke dashboard

- Buka `http://localhost:3000/login`
- Login dengan email/password user tadi

Expected:
- User `viewer` -> bisa `/app`, tidak bisa `/admin`
- User `staff` -> bisa `/app` dan `/admin`
- User `owner` -> bisa `/app` dan `/admin`, termasuk rotate credential device

Untuk admin password:
- Password awal di-set saat create user di Supabase Auth.
- Setelah login, user bisa ganti password di `/app/profile`.

## 5) Verifikasi cepat

1. Buka `/app`
- harus tampil tenant scope dan ringkasan telemetry.

2. Buka `/admin/devices`
- `staff/owner` bisa akses.
- `owner` melihat aksi rotate aktif.

## Troubleshooting

1. Login sukses tapi redirect ke `/unauthorized`
- cek `public.profiles` untuk user itu ada dan role valid.

2. Lupa password admin
- reset via Supabase Auth (Dashboard Supabase) atau login user lalu ganti di `/app/profile`.

3. Error env Supabase saat startup
- cek `apps/dashboard/.env.local`:
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `NEXT_PUBLIC_SUPABASE_ANON_KEY`

4. Data dashboard kosong
- cek apakah `tenant_id` profile sesuai dengan data di tabel `devices/telemetry`.

## SQL cek cepat

Cek profile user:

```sql
select p.id, p.tenant_id, p.role, p.full_name
from public.profiles p
where p.id = '<AUTH_USER_UUID>';
```

Cek data tenant:

```sql
select
  (select count(*) from public.devices d where d.tenant_id = '<TENANT_UUID>') as devices,
  (select count(*) from public.telemetry t where t.tenant_id = '<TENANT_UUID>') as telemetry_rows;
```
