-- Sprint 2: alerts and alert events for tenant monitoring.

create table if not exists public.alerts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  name text not null,
  metric text not null,
  operator text not null check (operator in ('gt', 'gte', 'lt', 'lte', 'eq')),
  threshold numeric not null,
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.alert_events (
  id bigserial primary key,
  alert_id uuid not null references public.alerts(id) on delete cascade,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  device_id uuid references public.devices(id) on delete set null,
  message text not null,
  triggered_at timestamptz not null default now()
);

create index if not exists idx_alerts_tenant_created_at
  on public.alerts (tenant_id, created_at desc);

create index if not exists idx_alert_events_tenant_triggered_at
  on public.alert_events (tenant_id, triggered_at desc);

grant select, insert, update, delete on public.alerts to authenticated;
grant select, insert on public.alert_events to authenticated;
grant usage, select on sequence public.alert_events_id_seq to authenticated;

alter table public.alerts enable row level security;
alter table public.alert_events enable row level security;

drop policy if exists alerts_tenant_select on public.alerts;
create policy alerts_tenant_select on public.alerts
for select
using (tenant_id = public.current_user_tenant_id());

drop policy if exists alerts_staff_write on public.alerts;
create policy alerts_staff_write on public.alerts
for all
using (
  tenant_id = public.current_user_tenant_id()
  and public.current_user_role() in ('owner', 'staff')
)
with check (
  tenant_id = public.current_user_tenant_id()
  and public.current_user_role() in ('owner', 'staff')
);

drop policy if exists alert_events_tenant_select on public.alert_events;
create policy alert_events_tenant_select on public.alert_events
for select
using (tenant_id = public.current_user_tenant_id());

drop policy if exists alert_events_staff_insert on public.alert_events;
create policy alert_events_staff_insert on public.alert_events
for insert
with check (
  tenant_id = public.current_user_tenant_id()
  and public.current_user_role() in ('owner', 'staff')
);
