-- Used only by CI: a plain Postgres made to look like the Supabase project
-- before the migrations (Supabase roles, default grants, the hand-made games table).
do $$ begin create role anon nologin; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated nologin; exception when duplicate_object then null; end $$;
grant usage on schema public to anon, authenticated;
alter default privileges in schema public grant all on tables to anon, authenticated;
alter default privileges in schema public grant all on sequences to anon, authenticated;
alter default privileges in schema public grant all on functions to anon, authenticated;
-- the state the new project is in today (old schema applied by hand)
create table public.games (id text primary key, title text not null, rules text not null, origin text default 'Community', tags text[] default '{}', topics text[] default '{}', created_at timestamptz default now());
alter table public.games enable row level security;
create policy "Enable read access for all users" on public.games for select using (true);
create policy "Enable insert for all users" on public.games for insert with check (true);
