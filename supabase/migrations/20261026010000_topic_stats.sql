-- Counters for "AIでお題を増やす" (POST /api/topics).
create or replace function public.bump_stat(stat_kind text) returns void
  language plpgsql security definer set search_path = public
  as $$
begin
  if stat_kind not in ('ai_ok', 'ai_error', 'ai_rate_limited', 'ai_invalid',
                       'topics_ok', 'topics_error', 'topics_rate_limited', 'topics_invalid') then
    raise exception 'unknown stat kind' using errcode = '22023';
  end if;
  insert into public.daily_stats (day, kind, count)
    values ((now() at time zone 'Asia/Tokyo')::date, stat_kind, 1)
    on conflict (day, kind) do update set count = daily_stats.count + 1;
end $$;
revoke all on function public.bump_stat(text) from public;
grant execute on function public.bump_stat(text) to anon, authenticated;
