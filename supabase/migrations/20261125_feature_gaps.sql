-- Migration for Aletheia feature gaps:
-- 1. Time of day: entries.happened_at date -> timestamptz
-- 2. Soft delete: entries.deleted_at timestamptz
-- 3. Photo management: media.sort_order, media.is_cover, entries.cover_media_id, and explicit delete policy on media

alter table entries
  alter column happened_at type timestamptz using happened_at::timestamptz,
  alter column happened_at set default now(),
  add column if not exists deleted_at timestamptz,
  add column if not exists cover_media_id uuid;

alter table media
  add column if not exists sort_order int not null default 0,
  add column if not exists is_cover boolean not null default false;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'entries_cover_media_fk'
  ) then
    alter table entries
      add constraint entries_cover_media_fk
      foreign key (cover_media_id) references media(id) on delete set null;
  end if;
end $$;

drop index if exists entries_user_date_idx;
create index if not exists entries_user_date_idx
  on entries (user_id, happened_at desc) where deleted_at is null;
create index if not exists entries_user_deleted_idx
  on entries (user_id, deleted_at) where deleted_at is not null;
create index if not exists media_entry_order_idx
  on media (entry_id, sort_order, storage_path);

-- Ensure update and delete policies exist on media if RLS was previously configured without them.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'media' and cmd in ('UPDATE', 'ALL')
  ) then
    create policy "update own media" on media for update to authenticated
      using (user_id = (select auth.uid()))
      with check (user_id = (select auth.uid()));
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'media' and cmd in ('DELETE', 'ALL')
  ) then
    create policy "delete own media" on media for delete to authenticated
      using (user_id = (select auth.uid()));
  end if;
end $$;
