-- Initial schema. Applied by tool/migrate.sh (CI); safe on a project that
-- already has the games table.

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

-- Reading is set up in 20261025000100_reports_and_limits.sql
-- (reported games are hidden).
