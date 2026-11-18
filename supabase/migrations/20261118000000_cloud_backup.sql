-- Kinledger cloud backup. Every row belongs to one signed-in person and nobody else can read it.
-- Rows are never deleted by the app: a deleted entry is a row with deleted_at set, and every
-- change keeps the previous payload in entry_versions.

create table public.entries (
  id uuid primary key,
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  -- The entry as the phone wrote it (CloudEntry JSON). The server never edits it.
  payload jsonb not null,
  -- When the person changed it, by the phone's clock. Decides which version wins.
  updated_at timestamptz not null,
  deleted_at timestamptz,
  -- When the server received it. Phones read changes after their last cursor.
  changed_at timestamptz not null default clock_timestamp()
);

create index entries_owner_changed on public.entries (owner_id, changed_at);

create table public.entry_versions (
  id bigint generated always as identity primary key,
  entry_id uuid not null,
  owner_id uuid not null references auth.users (id) on delete cascade,
  payload jsonb not null,
  replaced_at timestamptz not null default now()
);

create index entry_versions_entry on public.entry_versions (entry_id);

-- Stamp each write with the server clock, and keep the version it replaced.
create function public.entries_before_write() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.changed_at := clock_timestamp();
  if tg_op = 'UPDATE' then
    -- An older phone version never overwrites a newer one.
    if new.updated_at < old.updated_at then
      return null;
    end if;
    if new.owner_id <> old.owner_id then
      raise exception 'entries cannot change owner';
    end if;
    if new.payload is distinct from old.payload then
      insert into public.entry_versions (entry_id, owner_id, payload)
      values (old.id, old.owner_id, old.payload);
    end if;
  end if;
  return new;
end;
$$;

create trigger entries_before_write
before insert or update on public.entries
for each row execute function public.entries_before_write();

create table public.profiles (
  owner_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  payload jsonb not null,
  updated_at timestamptz not null,
  changed_at timestamptz not null default clock_timestamp()
);

alter table public.entries enable row level security;
alter table public.entry_versions enable row level security;
alter table public.profiles enable row level security;

create policy "own entries: read" on public.entries
  for select to authenticated using (owner_id = auth.uid());
create policy "own entries: add" on public.entries
  for insert to authenticated with check (owner_id = auth.uid());
create policy "own entries: change" on public.entries
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
-- No delete policy: the app has no way to remove a row.

create policy "own versions: read" on public.entry_versions
  for select to authenticated using (owner_id = auth.uid());

create policy "own profile: read" on public.profiles
  for select to authenticated using (owner_id = auth.uid());
create policy "own profile: add" on public.profiles
  for insert to authenticated with check (owner_id = auth.uid());
create policy "own profile: change" on public.profiles
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- Receipt photos: a private bucket, one folder per person named by their user id.
insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', false)
on conflict (id) do nothing;

create policy "own receipts: read" on storage.objects
  for select to authenticated
  using (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "own receipts: add" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "own receipts: replace" on storage.objects
  for update to authenticated
  using (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text);
