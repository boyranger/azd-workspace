-- Sprint 2: owner user-role management without recursive RLS checks.

grant usage on schema public to authenticated;
grant select on public.tenants to authenticated;
grant select on public.devices to authenticated;
grant select on public.telemetry to authenticated;
grant select, update (role) on public.profiles to authenticated;

create or replace function public.current_user_tenant_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select tenant_id from public.profiles where id = auth.uid() limit 1;
$$;

create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid() limit 1;
$$;

grant execute on function public.current_user_tenant_id() to authenticated;
grant execute on function public.current_user_role() to authenticated;

alter table public.profiles enable row level security;

drop policy if exists profiles_self_select on public.profiles;
create policy profiles_self_select on public.profiles
for select
using (id = auth.uid());

drop policy if exists profiles_owner_select_tenant on public.profiles;
create policy profiles_owner_select_tenant on public.profiles
for select
using (
  public.current_user_role() = 'owner'
  and tenant_id = public.current_user_tenant_id()
);

drop policy if exists profiles_owner_update_tenant on public.profiles;
create policy profiles_owner_update_tenant on public.profiles
for update
using (
  public.current_user_role() = 'owner'
  and tenant_id = public.current_user_tenant_id()
)
with check (
  tenant_id = public.current_user_tenant_id()
  and role in ('owner', 'staff', 'viewer')
);
