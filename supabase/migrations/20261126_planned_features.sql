-- Migration for Aletheia planned features:
-- 1. Feeling: entries.feeling text
-- 2. Albums: albums table + entries.album_id
-- 3. Upcoming Moments: entries.ends_at timestamptz + allow 'upcoming' in entries.type
-- 4. Expanded Profile: profiles table

-- 1. Albums table
create table if not exists albums (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title           text not null,
  description     text,
  cover_media_id  uuid references media(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists albums_user_created_idx
  on albums (user_id, created_at desc);

alter table albums enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'albums' and policyname = 'own albums'
  ) then
    create policy "own albums" on albums for all to authenticated
      using (user_id = (select auth.uid()))
      with check (user_id = (select auth.uid()));
  end if;
end $$;

-- 2. Entries updates: feeling, album_id, ends_at, and 'upcoming' type
alter table entries
  add column if not exists feeling text,
  add column if not exists album_id uuid references albums(id) on delete set null,
  add column if not exists ends_at timestamptz;

-- Replace the entries.type check constraint to include 'upcoming'
do $$
declare
  c_name text;
begin
  select conname into c_name
  from pg_constraint
  where conrelid = 'public.entries'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) like '%type%';

  if c_name is not null then
    execute format('alter table entries drop constraint %I', c_name);
  end if;

  alter table entries
    add constraint entries_type_check
    check (type in ('moment', 'place', 'game', 'anime', 'manga', 'upcoming'));
end $$;

create index if not exists entries_user_album_idx
  on entries (user_id, album_id)
  where deleted_at is null and album_id is not null;

create index if not exists entries_user_upcoming_idx
  on entries (user_id, happened_at)
  where deleted_at is null and type = 'upcoming';

-- 3. Profiles table
create table if not exists profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  display_name  text,
  avatar_path   text,
  updated_at    timestamptz not null default now()
);

alter table profiles enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'profiles' and policyname = 'own profile'
  ) then
    create policy "own profile" on profiles for all to authenticated
      using (id = (select auth.uid()))
      with check (id = (select auth.uid()));
  end if;
end $$;
