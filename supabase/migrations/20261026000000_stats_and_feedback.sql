-- Daily counters and ratings of AI-made games (2.1).
-- Applied by tool/migrate.sh (CI). Safe to run more than once.

-- 1. Daily counters of AI generation outcomes, bumped by the backend.
--    Only a day and a kind: nothing about who made the request.
--    Read by the weekly report (direct DB connection); not readable through the API.
create table if not exists public.daily_stats (
  day date not null,
  kind text not null,
  count integer not null default 0,
  primary key (day, kind)
);
alter table public.daily_stats enable row level security;
revoke all on public.daily_stats from anon, authenticated;

create or replace function public.bump_stat(stat_kind text) returns void
  language plpgsql security definer set search_path = public
  as $$
begin
  if stat_kind not in ('ai_ok', 'ai_error', 'ai_rate_limited', 'ai_invalid') then
    raise exception 'unknown stat kind' using errcode = '22023';
  end if;
  insert into public.daily_stats (day, kind, count)
    values ((now() at time zone 'Asia/Tokyo')::date, stat_kind, 1)
    on conflict (day, kind) do update set count = daily_stats.count + 1;
end $$;
revoke all on function public.bump_stat(text) from public;
grant execute on function public.bump_stat(text) to anon, authenticated;

-- 2. 👍 / 👎 on AI-made games. Anyone can rate; nobody can read ratings through the API.
create table if not exists public.ai_feedback (
  id bigint generated always as identity primary key,
  title text not null,
  rules text not null,
  tags text[] not null default '{}',
  good boolean not null,
  created_at timestamptz not null default now()
);
alter table public.ai_feedback drop constraint if exists ai_feedback_len;
alter table public.ai_feedback add constraint ai_feedback_len check (
  char_length(title) between 1 and 60
  and char_length(rules) between 1 and 1000
  and coalesce(array_length(tags, 1), 0) <= 10
);
alter table public.ai_feedback enable row level security;
drop policy if exists "Anyone can rate AI games" on public.ai_feedback;
create policy "Anyone can rate AI games" on public.ai_feedback for insert to anon, authenticated with check (true);
revoke all on public.ai_feedback from anon, authenticated;
grant insert on public.ai_feedback to anon, authenticated;
