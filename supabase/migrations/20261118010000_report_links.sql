-- Private report links. Family open them in a browser without an account; the token is the key,
-- so it is long and random (made on the phone) and can be revoked at any time.

create table public.report_links (
  token text primary key check (length(token) >= 40),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  period_start timestamptz not null,
  period_end timestamptz not null,
  include_notes boolean not null default false,
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);

alter table public.report_links enable row level security;

create policy "own links: read" on public.report_links
  for select to authenticated using (owner_id = auth.uid());
create policy "own links: add" on public.report_links
  for insert to authenticated with check (owner_id = auth.uid());
create policy "own links: revoke" on public.report_links
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- The only way to read a report without signing in. Returns null for an unknown or revoked link.
-- Notes are left out unless the caregiver chose to include them; trashed entries never appear.
create function public.shared_report(link_token text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'period_start', l.period_start,
    'period_end', l.period_end,
    'include_notes', l.include_notes,
    'profile', (select p.payload -> 'profile' from public.profiles p where p.owner_id = l.owner_id),
    'entries', coalesce((
      select jsonb_agg(
        case when l.include_notes then e.payload -> 'entry' else (e.payload -> 'entry') - 'note' end
        order by e.payload -> 'entry' ->> 'occurredAt'
      )
      from public.entries e
      where e.owner_id = l.owner_id
        and e.deleted_at is null
        and (e.payload -> 'entry' ->> 'occurredAt')::timestamptz >= l.period_start
        and (e.payload -> 'entry' ->> 'occurredAt')::timestamptz < l.period_end
    ), '[]'::jsonb)
  )
  from public.report_links l
  where l.token = link_token and l.revoked_at is null;
$$;

revoke all on function public.shared_report(text) from public;
grant execute on function public.shared_report(text) to anon, authenticated;
