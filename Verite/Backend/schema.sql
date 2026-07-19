-- Glowé — Supabase schema + Row Level Security.
-- Opt-in cloud sync of NUMBERS and routine only. No face photos are ever stored.
-- Run in the Supabase SQL editor after creating a project.

-- 1) Per-user numeric metrics (owner-only).
create table if not exists public.user_metrics (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  metrics    jsonb not null default '{}'::jsonb,   -- numbers + routine, never photos
  updated_at timestamptz not null default now()
);

alter table public.user_metrics enable row level security;

create policy "metrics are owner-only (select)"
  on public.user_metrics for select using (auth.uid() = user_id);
create policy "metrics are owner-only (upsert)"
  on public.user_metrics for insert with check (auth.uid() = user_id);
create policy "metrics are owner-only (update)"
  on public.user_metrics for update using (auth.uid() = user_id);

-- 2) Anonymized efficacy contributions (opt-in). No user id is exposed on read.
create table if not exists public.efficacy_records (
  id          bigint generated always as identity primary key,
  product_key text not null,
  skin_type   text,
  passed      boolean not null,
  created_at  timestamptz not null default now()
);

alter table public.efficacy_records enable row level security;

-- Anyone signed in (or anon, if you allow it) may contribute; nobody may read raw rows.
create policy "efficacy: insert only"
  on public.efficacy_records for insert with check (true);

-- 3) Public aggregate view — numbers only, no identities.
create or replace view public.community_efficacy as
  select
    product_key,
    skin_type,
    avg(case when passed then 1 else 0 end)::float as works_percent,
    count(*)::int as sample_size
  from public.efficacy_records
  group by product_key, skin_type
  having count(*) >= 5;   -- privacy: only surface aggregates with enough samples

grant select on public.community_efficacy to anon, authenticated;

-- 4) Apple-required account deletion: wipes the user's rows + auth account.
create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.user_metrics where user_id = auth.uid();
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_account() from public;
grant execute on function public.delete_account() to authenticated;
