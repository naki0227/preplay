#!/usr/bin/env bash
# Applies supabase/migrations/*.sql that have not been applied yet, in name
# order, each in its own transaction, then loads supabase/seed.sql.
# Applied names are kept in preplay_meta.applied_migrations (not exposed by the API).
#
#   DATABASE_URL=postgresql://... tool/migrate.sh            # apply
#   DATABASE_URL=postgresql://... tool/migrate.sh --dry-run  # only list pending
set -euo pipefail
: "${DATABASE_URL:?DATABASE_URL is not set}"
cd "$(dirname "$0")/.."
DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

psql_q() { psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -X -q "$@"; }

psql_q -c "create schema if not exists preplay_meta;
           create table if not exists preplay_meta.applied_migrations (
             name text primary key,
             applied_at timestamptz not null default now());"

pending=0
for f in supabase/migrations/*.sql; do
  name=$(basename "$f")
  if [ "$(psql_q -tAc "select 1 from preplay_meta.applied_migrations where name = '$name'")" = "1" ]; then
    echo "= $name (applied)"
    continue
  fi
  pending=$((pending + 1))
  if $DRY_RUN; then
    echo "+ $name (pending)"
    continue
  fi
  echo "+ $name"
  psql_q --single-transaction -f "$f" \
    -c "insert into preplay_meta.applied_migrations (name) values ('$name')"
done

if $DRY_RUN; then
  echo "$pending migration(s) would be applied; supabase/seed.sql would be loaded."
else
  psql_q -f supabase/seed.sql
  echo "Applied $pending migration(s); seed loaded."
fi
