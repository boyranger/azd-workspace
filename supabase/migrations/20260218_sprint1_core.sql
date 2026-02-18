-- Sprint 1 core schema scaffold for admin/user dashboard.

create extension if not exists pgcrypto;

create table if not exists public.tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  status text not null default 'active',
  plan text not null default 'starter',
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  full_name text,
  role text not null check (role in ('owner', 'staff', 'viewer')),
  created_at timestamptz not null default now()
);

create table if not exists public.devices (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  device_code text not null unique,
  name text not null,
  status text not null default 'active' check (status in ('active', 'disabled')),
  mqtt_username text not null,
  mqtt_password_hash text not null,
  last_seen_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.telemetry (
  id bigserial primary key,
  tenant_id uuid references public.tenants(id) on delete set null,
  device_id uuid references public.devices(id) on delete set null,
  topic text not null,
  payload_text text not null,
  payload_json jsonb,
  qos int not null default 0,
  retain boolean not null default false,
  received_at timestamptz not null,
  ingested_at timestamptz not null default now()
);

create index if not exists idx_telemetry_tenant_received_at
  on public.telemetry (tenant_id, received_at desc);

create index if not exists idx_telemetry_device_received_at
  on public.telemetry (device_id, received_at desc);

create index if not exists idx_devices_tenant_status
  on public.devices (tenant_id, status);

create index if not exists idx_profiles_tenant_role
  on public.profiles (tenant_id, role);

alter table public.tenants enable row level security;
alter table public.profiles enable row level security;
alter table public.devices enable row level security;
alter table public.telemetry enable row level security;

create or replace function public.current_tenant_id()
returns uuid
language sql
stable
as $$
  select tenant_id from public.profiles where id = auth.uid() limit 1;
$$;

drop policy if exists tenant_select_tenants on public.tenants;
create policy tenant_select_tenants on public.tenants
for select
using (id = public.current_tenant_id());

drop policy if exists tenant_select_profiles on public.profiles;
create policy tenant_select_profiles on public.profiles
for select
using (tenant_id = public.current_tenant_id());

drop policy if exists tenant_select_devices on public.devices;
create policy tenant_select_devices on public.devices
for select
using (tenant_id = public.current_tenant_id());

drop policy if exists tenant_select_telemetry on public.telemetry;
create policy tenant_select_telemetry on public.telemetry
for select
using (tenant_id = public.current_tenant_id());

-- owner/staff write policy for devices
drop policy if exists tenant_write_devices on public.devices;
create policy tenant_write_devices on public.devices
for all
using (
  tenant_id = public.current_tenant_id()
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.tenant_id = public.devices.tenant_id
      and p.role in ('owner', 'staff')
  )
)
with check (
  tenant_id = public.current_tenant_id()
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.tenant_id = public.devices.tenant_id
      and p.role in ('owner', 'staff')
  )
);
