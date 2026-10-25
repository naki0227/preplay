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

reset role;
select 'policies ok';
