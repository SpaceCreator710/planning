-- Planning account/data security deployed to Supabase project xlopoistxuihnhjtentb.
-- User cloud snapshots are isolated with RLS. Account deletion is recoverable for seven days,
-- then a pg_cron job permanently removes the Auth user and cascaded Planning data.

create table if not exists public.account_deletion_requests (
  user_id uuid primary key references auth.users(id) on delete cascade,
  requested_at timestamptz not null default now(),
  restore_until timestamptz not null default (now() + interval '7 days'),
  updated_at timestamptz not null default now()
);

create table if not exists public.app_snapshots (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.account_deletion_requests enable row level security;
alter table public.app_snapshots enable row level security;

create or replace function public.planning_account_is_active(target_user uuid)
returns boolean
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  select not exists (
    select 1
    from public.account_deletion_requests r
    where r.user_id = target_user
      and r.user_id = (select auth.uid())
  );
$$;

revoke all on function public.planning_account_is_active(uuid) from public, anon;
grant execute on function public.planning_account_is_active(uuid) to authenticated;

drop policy if exists "users_read_own_deletion_status" on public.account_deletion_requests;
create policy "users_read_own_deletion_status" on public.account_deletion_requests
for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "users_read_active_snapshot" on public.app_snapshots;
create policy "users_read_active_snapshot" on public.app_snapshots
for select to authenticated
using ((select auth.uid()) = user_id and public.planning_account_is_active(user_id));

drop policy if exists "users_insert_active_snapshot" on public.app_snapshots;
create policy "users_insert_active_snapshot" on public.app_snapshots
for insert to authenticated
with check ((select auth.uid()) = user_id and public.planning_account_is_active(user_id));

drop policy if exists "users_update_active_snapshot" on public.app_snapshots;
create policy "users_update_active_snapshot" on public.app_snapshots
for update to authenticated
using ((select auth.uid()) = user_id and public.planning_account_is_active(user_id))
with check ((select auth.uid()) = user_id and public.planning_account_is_active(user_id));

drop policy if exists "users_delete_active_snapshot" on public.app_snapshots;
create policy "users_delete_active_snapshot" on public.app_snapshots
for delete to authenticated
using ((select auth.uid()) = user_id and public.planning_account_is_active(user_id));

revoke all on public.account_deletion_requests from anon;
revoke all on public.account_deletion_requests from authenticated;
grant select on public.account_deletion_requests to authenticated;
revoke all on public.app_snapshots from anon;
grant select, insert, update, delete on public.app_snapshots to authenticated;

create or replace function public.purge_expired_planning_accounts()
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  delete from auth.users u
  using public.account_deletion_requests r
  where u.id = r.user_id
    and r.restore_until <= now();
end;
$$;
revoke all on function public.purge_expired_planning_accounts() from public, anon, authenticated;

create extension if not exists pg_cron with schema pg_catalog;
create index if not exists account_deletion_requests_restore_until_idx
  on public.account_deletion_requests (restore_until);

-- Schedule once per hour. If already scheduled, run the unschedule block before applying again.
-- select cron.schedule('purge-expired-planning-accounts','17 * * * *',
--   $$select public.purge_expired_planning_accounts();$$);
