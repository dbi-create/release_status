-- Catalog rows must broadcast so Mac/iPhone stay in sync after a channel
-- is added or verified on one device.
alter table public.release_status_titles replica identity full;
alter table public.release_status_platforms replica identity full;

do $$
begin
  begin
    alter publication supabase_realtime add table public.release_status_titles;
  exception
    when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.release_status_platforms;
  exception
    when duplicate_object then null;
  end;
end $$;
