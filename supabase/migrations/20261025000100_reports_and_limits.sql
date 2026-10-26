-- Report table, posting limits and hiding reported games.
-- Applied by tool/migrate.sh (CI). Safe to run more than once.

-- 1. Limits on what can be posted to "みんなの遊び" (the anon key can insert directly).
alter table public.games drop constraint if exists games_title_len;
alter table public.games add constraint games_title_len check (char_length(title) between 1 and 60);
alter table public.games drop constraint if exists games_rules_len;
alter table public.games add constraint games_rules_len check (char_length(rules) between 1 and 1000);
alter table public.games drop constraint if exists games_origin_len;
alter table public.games add constraint games_origin_len check (origin is null or char_length(origin) <= 60);
alter table public.games drop constraint if exists games_arrays_len;
alter table public.games add constraint games_arrays_len
  check (coalesce(array_length(tags, 1), 0) <= 10 and coalesce(array_length(topics, 1), 0) <= 50);

-- 2. Reports. Anyone can report; nobody can read reports through the API.
create table if not exists public.reports (
  id bigint generated always as identity primary key,
  game_id text not null references public.games(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.reports enable row level security;
drop policy if exists "Anyone can report" on public.reports;
create policy "Anyone can report" on public.reports for insert to anon, authenticated with check (true);
grant insert on public.reports to anon, authenticated;

-- 3. Hide games with 3 or more reports from everyone.
--    security definer: the read policy must count reports anon cannot select.
create or replace function public.report_count(gid text) returns integer
  language sql stable security definer set search_path = public
  as $$ select count(*)::int from public.reports where game_id = gid $$;
revoke all on function public.report_count(text) from public;
grant execute on function public.report_count(text) to anon, authenticated;

drop policy if exists "Enable read access for all users" on public.games;
drop policy if exists "Read games that are not reported" on public.games;
create policy "Read games that are not reported" on public.games
  for select using (public.report_count(id) < 3);
