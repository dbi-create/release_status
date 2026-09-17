-- Live alerts for closed devices: upsert-friendly catalog + APNs outbox.
create extension if not exists pg_net;

alter table public.release_status_profiles
  add column if not exists live_alerts_enabled boolean not null default true;

create table if not exists public.release_status_live_alert_log (
  owner_user_id uuid not null references auth.users (id) on delete cascade,
  title_id text not null,
  platform_name text not null,
  sent_at timestamptz not null default now(),
  primary key (owner_user_id, title_id, platform_name)
);

create table if not exists public.release_status_notify_config (
  id integer primary key default 1 check (id = 1),
  function_url text not null,
  auth_bearer text not null default ''
);

alter table public.release_status_live_alert_log enable row level security;
alter table public.release_status_notify_config enable row level security;

revoke all on table public.release_status_notify_config from public, anon, authenticated;
revoke all on table public.release_status_live_alert_log from public, anon, authenticated;
grant select, insert, update, delete on table public.release_status_live_alert_log
  to service_role;

drop policy if exists "release_status_live_alert_log_owner_insert"
  on public.release_status_live_alert_log;
create policy "release_status_live_alert_log_owner_insert"
  on public.release_status_live_alert_log
  for all
  to authenticated
  using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());

create or replace function public.release_status_claim_live_alert(
  p_owner uuid,
  p_title_id text,
  p_platform text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  changed integer := 0;
begin
  insert into public.release_status_live_alert_log (
    owner_user_id,
    title_id,
    platform_name,
    sent_at
  )
  values (p_owner, p_title_id, p_platform, now())
  on conflict (owner_user_id, title_id, platform_name)
  do update set sent_at = now()
  where public.release_status_live_alert_log.sent_at < now() - interval '20 minutes';

  get diagnostics changed = row_count;
  return changed > 0;
end;
$$;

revoke all on function public.release_status_claim_live_alert(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.release_status_claim_live_alert(uuid, text, text)
  to service_role, authenticated;

create or replace function public.release_status_notify_on_live()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  cfg record;
  title_name text;
  alerts_on boolean;
  title_created timestamptz;
  claimed boolean;
begin
  if new.status is distinct from 'live' then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.status is not distinct from 'live' then
    return new;
  end if;

  select live_alerts_enabled into alerts_on
  from public.release_status_profiles
  where user_id = new.owner_user_id;
  if alerts_on is false then
    return new;
  end if;

  select name, created_at into title_name, title_created
  from public.release_status_titles
  where owner_user_id = new.owner_user_id
    and id = new.title_id;
  if title_name is null then
    return new;
  end if;

  if tg_op = 'INSERT'
    and title_created is not null
    and title_created > now() - interval '10 minutes' then
    return new;
  end if;

  select * into cfg from public.release_status_notify_config where id = 1;
  if cfg.function_url is null or coalesce(cfg.auth_bearer, '') = '' then
    return new;
  end if;

  select public.release_status_claim_live_alert(
    new.owner_user_id,
    new.title_id,
    new.platform_name
  ) into claimed;
  if not claimed then
    return new;
  end if;

  perform net.http_post(
    url := cfg.function_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', cfg.auth_bearer
    ),
    body := jsonb_build_object(
      'owner_user_id', new.owner_user_id,
      'title', title_name || ' is live',
      'body', 'Now live on ' || new.platform_name || '.',
      'title_id', new.title_id,
      'platform_name', new.platform_name,
      'claimed', true
    )
  );
  return new;
end;
$$;

drop trigger if exists tr_release_status_platforms_notify_live
  on public.release_status_platforms;
create trigger tr_release_status_platforms_notify_live
  after insert or update of status
  on public.release_status_platforms
  for each row
  execute procedure public.release_status_notify_on_live();

insert into public.release_status_notify_config (id, function_url, auth_bearer)
values (
  1,
  'https://bbwoflcbndynondfymqb.supabase.co/functions/v1/release-status-notify',
  ''
)
on conflict (id) do nothing;
