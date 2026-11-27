-- Aletheia: Supabase schema
-- Run this in the Supabase Dashboard > SQL Editor.

-- ============ TABLES ============

create table places (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name        text not null,
  lat         double precision not null,
  lng         double precision not null,
  created_at  timestamptz not null default now()
);

create table entries (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null default auth.uid() references auth.users(id) on delete cascade,
  type            text not null check (type in ('moment', 'place', 'game', 'anime', 'manga', 'upcoming')),
  title           text not null,
  note            text,
  feeling         text,
  happened_at     timestamptz not null default now(),
  ends_at         timestamptz,
  place_id        uuid references places(id) on delete set null,
  album_id        uuid,
  cover_media_id  uuid,
  deleted_at      timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create table media (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  entry_id      uuid not null references entries(id) on delete cascade,
  storage_path  text not null,
  sort_order    int not null default 0,
  is_cover      boolean not null default false,
  taken_at      timestamptz,
  caption       text
);

alter table entries
  add constraint entries_cover_media_fk
  foreign key (cover_media_id) references media(id) on delete set null;

create table albums (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title           text not null,
  description     text,
  cover_media_id  uuid references media(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

alter table entries
  add constraint entries_album_fk
  foreign key (album_id) references albums(id) on delete set null;

create table profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  display_name  text,
  avatar_path   text,
  updated_at    timestamptz not null default now()
);

create table tags (
  id       uuid primary key default gen_random_uuid(),
  user_id  uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name     text not null,
  unique (user_id, name)
);

create table entry_tags (
  entry_id  uuid not null references entries(id) on delete cascade,
  tag_id    uuid not null references tags(id) on delete cascade,
  primary key (entry_id, tag_id)
);

-- Only used for game / anime / manga entries
create table progress (
  entry_id     uuid primary key references entries(id) on delete cascade,
  status       text not null check (status in ('planned', 'in_progress', 'completed', 'dropped')),
  current      int not null default 0,
  total        int,
  unit         text check (unit in ('episodes', 'chapters', 'hours', 'percent')),
  rating       int check (rating between 1 and 10),
  started_on   date,
  finished_on  date
);

-- Helpful indexes
create index entries_user_date_idx on entries (user_id, happened_at desc) where deleted_at is null;
create index entries_user_deleted_idx on entries (user_id, deleted_at) where deleted_at is not null;
create index entries_user_album_idx on entries (user_id, album_id) where deleted_at is null and album_id is not null;
create index entries_user_upcoming_idx on entries (user_id, happened_at) where deleted_at is null and type = 'upcoming';
create index media_entry_order_idx on media (entry_id, sort_order, storage_path);
create index albums_user_created_idx on albums (user_id, created_at desc);

-- ============ ROW LEVEL SECURITY ============
-- Only the logged-in owner can see or change their own rows.

alter table places      enable row level security;
alter table entries     enable row level security;
alter table media       enable row level security;
alter table tags        enable row level security;
alter table entry_tags  enable row level security;
alter table progress    enable row level security;
alter table albums      enable row level security;
alter table profiles    enable row level security;

create policy "own places" on places for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "own entries" on entries for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "own media" on media for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "own tags" on tags for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- These two have no user_id, so ownership is checked through the parent entry.
create policy "own entry_tags" on entry_tags for all to authenticated
  using (exists (
    select 1 from entries e
    where e.id = entry_tags.entry_id and e.user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from entries e
    where e.id = entry_tags.entry_id and e.user_id = (select auth.uid())
  ));

create policy "own progress" on progress for all to authenticated
  using (exists (
    select 1 from entries e
    where e.id = progress.entry_id and e.user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from entries e
    where e.id = progress.entry_id and e.user_id = (select auth.uid())
  ));

create policy "own albums" on albums for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "own profile" on profiles for all to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- ============ PHOTO STORAGE ============
-- Private bucket. Files must be stored under a folder named after the user's id:
--   <user_id>/<entry_id>/<filename>

insert into storage.buckets (id, name, public)
values ('memories', 'memories', false)
on conflict (id) do nothing;

create policy "own memory files" on storage.objects for all to authenticated
  using (
    bucket_id = 'memories'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'memories'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );