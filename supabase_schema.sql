-- Create the games table
create table public.games (
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

-- Policy: Allow everyone to read games
create policy "Enable read access for all users" on public.games
  for select using (true);

-- Policy: Allow everyone to insert games (For MVP.Ideally authenticated)
create policy "Enable insert for all users" on public.games
  for insert with check (true);
