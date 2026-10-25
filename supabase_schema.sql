-- Fresh setup for the Preplay Supabase project. Run in the SQL Editor, then
-- run supabase/migration_2026-10-25.sql and supabase/seed.sql.

-- Create the games table
create table if not exists public.games (
  id text primary key, -- client-generated ID or uuid
  title text not null,
  rules text not null,
  origin text default 'Community',
  tags text[] default '{}',
  topics text[] default '{}',
  created_at timestamptz default now()
);

-- Enable Row Level Security (RLS)
alter table public.games enable row level security;

-- Policy: Allow everyone to insert games (For MVP.Ideally authenticated)
drop policy if exists "Enable insert for all users" on public.games;
create policy "Enable insert for all users" on public.games
  for insert with check (true);

-- Reading is set up in supabase/migration_2026-10-25.sql
-- (reported games are hidden).
