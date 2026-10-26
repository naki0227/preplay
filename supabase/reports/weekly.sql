-- Numbers for the last 7 full days (Japan time), printed as Markdown.
-- Run by .github/workflows/weekly-report.yml with the database owner's connection.
\pset tuples_only on
\pset format unaligned
\pset footer off

create temp table report_days as
  select generate_series(
    (now() at time zone 'Asia/Tokyo')::date - 7,
    (now() at time zone 'Asia/Tokyo')::date - 1,
    interval '1 day')::date as day;
-- [from, to) as timestamps
create temp view report_range as
  select (min(day)::timestamp at time zone 'Asia/Tokyo') as since,
         ((max(day) + 1)::timestamp at time zone 'Asia/Tokyo') as until
  from report_days;

-- 1. AI generation
select E'## AIで遊びを作った回数\n\n'
    || E'| 日付 | 成功 | 失敗 | 混雑で断った | 不正な要求 |\n|---|---:|---:|---:|---:|\n'
    || string_agg(format('| %s | %s | %s | %s | %s |', to_char(d.day, 'MM/DD (Dy)'),
         coalesce((select count from public.daily_stats s where s.day = d.day and s.kind = 'ai_ok'), 0),
         coalesce((select count from public.daily_stats s where s.day = d.day and s.kind = 'ai_error'), 0),
         coalesce((select count from public.daily_stats s where s.day = d.day and s.kind = 'ai_rate_limited'), 0),
         coalesce((select count from public.daily_stats s where s.day = d.day and s.kind = 'ai_invalid'), 0)),
       E'\n' order by d.day)
    || format(E'\n| **合計** | **%s** | **%s** | **%s** | **%s** |\n',
         coalesce((select sum(count) from public.daily_stats s join report_days r using (day) where s.kind = 'ai_ok'), 0),
         coalesce((select sum(count) from public.daily_stats s join report_days r using (day) where s.kind = 'ai_error'), 0),
         coalesce((select sum(count) from public.daily_stats s join report_days r using (day) where s.kind = 'ai_rate_limited'), 0),
         coalesce((select sum(count) from public.daily_stats s join report_days r using (day) where s.kind = 'ai_invalid'), 0))
from report_days d;

select format(E'\nAIでお題を増やした回数: 成功 %s ／ 失敗 %s\n',
  coalesce((select sum(count) from public.daily_stats s join report_days r using (day) where s.kind = 'topics_ok'), 0),
  coalesce((select sum(count) from public.daily_stats s join report_days r using (day) where s.kind = 'topics_error'), 0));

-- 2. Ratings of AI games
with f as (
  select * from public.ai_feedback, report_range
  where created_at >= since and created_at < until
), by_game as (
  select replace(replace(title, '|', '／'), E'\n', ' ') as title,
         count(*) filter (where good) as good, count(*) filter (where not good) as bad,
         left(replace(replace(min(rules), '|', '／'), E'\n', ' '), 80) as rules
  from f group by 1
)
select format(E'\n## AIの遊びの評価\n\n👍 %s ／ 👎 %s（👍の割合 %s）\n',
         (select count(*) filter (where good) from f),
         (select count(*) filter (where not good) from f),
         coalesce(round(100.0 * (select count(*) filter (where good) from f) / nullif((select count(*) from f), 0)) || '%', '—'))
    || coalesce(E'\n**👍が多かった遊び**（「みんなの遊び」に載せる候補）\n\n| 遊び | 👍 | 👎 | 遊び方 |\n|---|---:|---:|---|\n'
         || (select string_agg(format('| %s | %s | %s | %s |', title, good, bad, rules), E'\n')
             from (select * from by_game where good > 0 order by good desc, bad limit 5) t) || E'\n', '')
    || coalesce(E'\n**👎が多かった遊び**（AIへの指示を直す材料）\n\n| 遊び | 👍 | 👎 | 遊び方 |\n|---|---:|---:|---|\n'
         || (select string_agg(format('| %s | %s | %s | %s |', title, good, bad, rules), E'\n')
             from (select * from by_game where bad > 0 order by bad desc, good limit 5) t) || E'\n', '');

-- 3. Community
select format(E'\n## みんなの遊び\n\n- 新しい投稿: %s 件（全部で %s 件）\n- 通報: %s 件\n- 通報が3件以上で非表示になっている遊び: %s 件\n',
  (select count(*) from public.games, report_range where origin is distinct from 'Preplay Official' and created_at >= since and created_at < until),
  (select count(*) from public.games where origin is distinct from 'Preplay Official'),
  (select count(*) from public.reports, report_range where created_at >= since and created_at < until),
  (select count(*) from public.games where public.report_count(id) >= 3));
