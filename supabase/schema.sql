-- Plan Your Day: minimal secure cloud schema.
-- Run once in the Supabase SQL editor. Client access is protected with RLS.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  locale text not null default 'en',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.app_snapshots (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.subscriptions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  tier text not null default 'free' check (tier in ('free', 'plus', 'pro', 'max')),
  status text not null default 'inactive' check (status in ('inactive', 'trialing', 'active', 'past_due', 'canceled', 'expired')),
  provider text check (provider in ('app_store', 'google_play', 'paypal', 'card', 'ru_card', 'manual')),
  provider_customer_id text,
  provider_subscription_id text,
  current_period_end timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.billing_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  provider_event_id text not null unique,
  event_type text not null,
  user_id uuid references auth.users(id) on delete set null,
  received_at timestamptz not null default now(),
  payload jsonb not null default '{}'::jsonb
);

alter table public.profiles enable row level security;
alter table public.app_snapshots enable row level security;
alter table public.subscriptions enable row level security;
alter table public.billing_events enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles for select using (auth.uid() = user_id);
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles for insert with check (auth.uid() = user_id);
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "snapshots_select_own" on public.app_snapshots;
create policy "snapshots_select_own" on public.app_snapshots for select using (auth.uid() = user_id);
drop policy if exists "snapshots_insert_own" on public.app_snapshots;
create policy "snapshots_insert_own" on public.app_snapshots for insert with check (auth.uid() = user_id);
drop policy if exists "snapshots_update_own" on public.app_snapshots;
create policy "snapshots_update_own" on public.app_snapshots for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "snapshots_delete_own" on public.app_snapshots;
create policy "snapshots_delete_own" on public.app_snapshots for delete using (auth.uid() = user_id);

drop policy if exists "subscriptions_select_own" on public.subscriptions;
create policy "subscriptions_select_own" on public.subscriptions for select using (auth.uid() = user_id);

-- There are deliberately no client INSERT/UPDATE policies for subscriptions
-- or billing_events. Only verified server webhooks using the service role may
-- grant an entitlement.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (user_id, display_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (user_id) do nothing;

  insert into public.subscriptions (user_id, tier, status)
  values (new.id, 'free', 'inactive')
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create index if not exists billing_events_user_id_idx on public.billing_events(user_id);
create index if not exists billing_events_received_at_idx on public.billing_events(received_at desc);
