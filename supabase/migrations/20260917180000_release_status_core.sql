-- Release Status tables on the shared Orbium Supabase project.
-- Prefix rule: release_status_* only. Do not touch ezopezo_, recordme_, or okis_ tables.

create or replace function public.set_release_status_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.release_status_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  monitoring_enabled boolean not null default true,
  check_interval_hours integer not null default 24
    check (check_interval_hours > 0),
  last_completed_check_at timestamptz,
  notifications_cleared_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.release_status_titles (
  owner_user_id uuid not null references auth.users (id) on delete cascade,
  id text not null,
  name text not null,
  release_year integer not null,
  content_type text not null,
  placeholder_color bigint not null default 0,
  imdb_id text,
  tmdb_id text,
  availability_provider_id text,
  poster_url text,
  director text,
  producer text,
  writer text,
  alternate_title text,
  pinned boolean not null default false,
  last_looked_up_at timestamptz,
  discovered_platforms jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (owner_user_id, id)
);

create index if not exists idx_release_status_titles_owner
  on public.release_status_titles (owner_user_id);

create index if not exists idx_release_status_titles_tmdb
  on public.release_status_titles (tmdb_id)
  where tmdb_id is not null;

create table if not exists public.release_status_platforms (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null,
  title_id text not null,
  platform_name text not null,
  status text not null
    check (status in ('live', 'waiting', 'originalNetwork', 'removed')),
  origin text not null default 'manual',
  license_relationship text,
  first_detected_at timestamptz,
  last_checked_at timestamptz,
  removed_at timestamptz,
  status_message text,
  status_detail text,
  evidence_source text,
  evidence_url text,
  last_monitoring_source text,
  last_match_confidence text,
  last_check_failed boolean not null default false,
  consecutive_verified_absences integer not null default 0,
  source_provider_id text,
  history jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_user_id, title_id, platform_name),
  foreign key (owner_user_id, title_id)
    references public.release_status_titles (owner_user_id, id)
    on delete cascade
);

create index if not exists idx_release_status_platforms_title
  on public.release_status_platforms (owner_user_id, title_id);

create table if not exists public.release_status_tmdb_facts (
  tmdb_id text primary key,
  content_type text not null,
  name text,
  release_year integer,
  poster_url text,
  us_watch_providers jsonb not null default '[]'::jsonb,
  original_networks jsonb not null default '[]'::jsonb,
  last_checked_at timestamptz,
  last_error text,
  updated_at timestamptz not null default now()
);

create table if not exists public.release_status_push_tokens (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users (id) on delete cascade,
  device_token text not null,
  platform text not null default 'ios',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_user_id, device_token)
);

create index if not exists idx_release_status_push_tokens_owner
  on public.release_status_push_tokens (owner_user_id);

drop trigger if exists tr_release_status_profiles_updated_at
  on public.release_status_profiles;
create trigger tr_release_status_profiles_updated_at
  before update on public.release_status_profiles
  for each row execute function public.set_release_status_updated_at();

drop trigger if exists tr_release_status_titles_updated_at
  on public.release_status_titles;
create trigger tr_release_status_titles_updated_at
  before update on public.release_status_titles
  for each row execute function public.set_release_status_updated_at();

drop trigger if exists tr_release_status_platforms_updated_at
  on public.release_status_platforms;
create trigger tr_release_status_platforms_updated_at
  before update on public.release_status_platforms
  for each row execute function public.set_release_status_updated_at();

drop trigger if exists tr_release_status_tmdb_facts_updated_at
  on public.release_status_tmdb_facts;
create trigger tr_release_status_tmdb_facts_updated_at
  before update on public.release_status_tmdb_facts
  for each row execute function public.set_release_status_updated_at();

drop trigger if exists tr_release_status_push_tokens_updated_at
  on public.release_status_push_tokens;
create trigger tr_release_status_push_tokens_updated_at
  before update on public.release_status_push_tokens
  for each row execute function public.set_release_status_updated_at();

alter table public.release_status_profiles enable row level security;
alter table public.release_status_titles enable row level security;
alter table public.release_status_platforms enable row level security;
alter table public.release_status_tmdb_facts enable row level security;
alter table public.release_status_push_tokens enable row level security;

drop policy if exists "release_status_profiles_owner_all"
  on public.release_status_profiles;
create policy "release_status_profiles_owner_all"
  on public.release_status_profiles for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "release_status_titles_owner_all"
  on public.release_status_titles;
create policy "release_status_titles_owner_all"
  on public.release_status_titles for all
  to authenticated
  using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());

drop policy if exists "release_status_platforms_owner_all"
  on public.release_status_platforms;
create policy "release_status_platforms_owner_all"
  on public.release_status_platforms for all
  to authenticated
  using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());

drop policy if exists "release_status_push_tokens_owner_all"
  on public.release_status_push_tokens;
create policy "release_status_push_tokens_owner_all"
  on public.release_status_push_tokens for all
  to authenticated
  using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());

drop policy if exists "release_status_tmdb_facts_authenticated_select"
  on public.release_status_tmdb_facts;
create policy "release_status_tmdb_facts_authenticated_select"
  on public.release_status_tmdb_facts for select
  to authenticated
  using (true);
