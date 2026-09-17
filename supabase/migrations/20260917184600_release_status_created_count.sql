alter table public.release_status_profiles
  add column if not exists catalog_created_count integer not null default 0;
