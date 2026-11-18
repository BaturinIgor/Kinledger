-- Explicit table rights, so the app works whether or not the project exposes new tables
-- to the Data API automatically. Row-level security still limits every row to its owner.
-- Nobody without an account reads tables directly: family use shared_report() only.

revoke all on public.entries, public.entry_versions, public.profiles, public.report_links
  from anon, authenticated;

grant select, insert, update on public.entries to authenticated;
grant select on public.entry_versions to authenticated;
grant select, insert, update on public.profiles to authenticated;
grant select, insert, update on public.report_links to authenticated;
