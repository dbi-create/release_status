-- Server-side 12h catalog checks. GitHub Actions is the primary clock;
-- pg_cron is a backup if the extension is available.
create table if not exists public.release_status_check_lock (
  id integer primary key default 1 check (id = 1),
  locked_until timestamptz not null default to_timestamp(0),
  updated_at timestamptz not null default now()
);

alter table public.release_status_check_lock enable row level security;
revoke all on table public.release_status_check_lock from public, anon, authenticated;
grant select, insert, update, delete on table public.release_status_check_lock
  to service_role;

insert into public.release_status_check_lock (id, locked_until)
values (1, to_timestamp(0))
on conflict (id) do nothing;

alter table public.release_status_notify_config
  add column if not exists check_url text;

update public.release_status_notify_config
set check_url = 'https://bbwoflcbndynondfymqb.supabase.co/functions/v1/release-status-check'
where id = 1
  and coalesce(check_url, '') = '';

do $$
begin
  create extension if not exists pg_cron;
exception
  when others then
    raise notice 'pg_cron unavailable; GitHub Actions remains the 12h clock';
end
$$;

do $$
begin
  perform cron.unschedule('release_status_check_12h');
exception
  when others then
    null;
end
$$;

do $$
begin
  perform cron.schedule(
    'release_status_check_12h',
    '0 */12 * * *',
    $job$
    select net.http_post(
      url := (
        select coalesce(
          check_url,
          'https://bbwoflcbndynondfymqb.supabase.co/functions/v1/release-status-check'
        )
        from public.release_status_notify_config
        where id = 1
      ),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', (
          select auth_bearer
          from public.release_status_notify_config
          where id = 1
        )
      ),
      body := '{"source":"cron"}'::jsonb
    );
    $job$
  );
exception
  when others then
    raise notice 'could not schedule release_status_check_12h';
end
$$;
