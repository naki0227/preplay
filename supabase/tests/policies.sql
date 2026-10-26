-- Checks the rules the app relies on. Run by CI against a throwaway Postgres
-- after tool/migrate.sh; any failed check raises and fails the job.
set role anon;

do $$ begin
  if (select count(*) from public.games where origin = 'Preplay Official') <> 42 then
    raise exception 'expected 42 official games';
  end if;
end $$;

-- anon can post a normal AI game
insert into public.games (id, title, rules, origin, tags) values ('ai_ci', 'テスト', 'ルール', 'AI (quiet)', array['quiet']);

-- anon cannot post oversized text
do $$ begin
  begin
    insert into public.games (id, title, rules) values ('ci_long', repeat('a', 61), 'r');
    raise exception 'oversized title was accepted';
  exception when check_violation then null;
  end;
end $$;

-- anon cannot change or delete games (no policy)
update public.games set title = 'x' where id = 'ai_ci';
delete from public.games where id = 'ai_ci';
do $$ begin
  if (select title from public.games where id = 'ai_ci') <> 'テスト' then
    raise exception 'anon could change or delete a game';
  end if;
end $$;

-- 3 reports hide a game from everyone; reports themselves are not readable
insert into public.reports (game_id) values ('ai_ci'), ('ai_ci'), ('ai_ci');
do $$ begin
  if exists (select 1 from public.games where id = 'ai_ci') then
    raise exception 'reported game is still visible';
  end if;
end $$;
-- (Supabase grants anon SELECT on every table; RLS without a select policy returns no rows.)
do $$ begin
  if (select count(*) from public.reports) > 0 then
    raise exception 'anon can read reports';
  end if;
end $$;

-- the backend can bump daily counters, only known kinds, and cannot read them
do $$ begin
  perform public.bump_stat('ai_ok');
  perform public.bump_stat('ai_ok');
  perform public.bump_stat('ai_error');
  begin
    perform public.bump_stat('anything else');
    raise exception 'unknown stat kind was accepted';
  exception when invalid_parameter_value then null;
  end;
  begin
    perform count(*) from public.daily_stats;
    raise exception 'anon can read daily_stats';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.daily_stats (day, kind, count) values (current_date, 'ai_ok', 1000);
    raise exception 'anon can write daily_stats directly';
  exception when insufficient_privilege then null;
  end;
end $$;

-- anyone can rate an AI game; ratings are not readable and have size limits
insert into public.ai_feedback (title, rules, tags, good) values ('AIの遊び', 'ルール', array['quiet'], true);
do $$ begin
  begin
    insert into public.ai_feedback (title, rules, good) values (repeat('a', 61), 'r', false);
    raise exception 'oversized rating was accepted';
  exception when check_violation then null;
  end;
  begin
    perform count(*) from public.ai_feedback;
    raise exception 'anon can read ai_feedback';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;

do $$ begin
  if (select count from public.daily_stats where kind = 'ai_ok') <> 2
     or (select count from public.daily_stats where kind = 'ai_error') <> 1 then
    raise exception 'daily_stats did not count';
  end if;
  if (select count(*) from public.ai_feedback) <> 1 then
    raise exception 'rating was not stored';
  end if;
end $$;

-- the weekly report runs as the database owner
\o /dev/null
\i supabase/reports/weekly.sql
\o
select 'policies ok';
