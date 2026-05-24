#!/usr/bin/env sh
set -eu

DB_CONTAINER="${HONCHO_DB_CONTAINER:-honcho-db}"

psql_exec() {
  docker exec "$DB_CONTAINER" psql -U postgres -d postgres "$@"
}

echo "== Honcho counts =="
psql_exec -c "
select 'workspaces' as table, count(*) from workspaces
union all select 'peers', count(*) from peers
union all select 'sessions', count(*) from sessions
union all select 'messages', count(*) from messages
union all select 'queue', count(*) from queue
union all select 'documents', count(*) from documents
union all select 'collections', count(*) from collections
union all select 'message_embeddings', count(*) from message_embeddings;
"

echo
echo "== Workspaces =="
psql_exec -c "select id, name, created_at from workspaces order by created_at desc;"

echo
echo "== Peers =="
psql_exec -c "select id, workspace_name, name, created_at from peers order by created_at desc;"

echo
echo "== Sessions =="
psql_exec -c "select id, workspace_name, name, created_at from sessions order by created_at desc limit 20;"

echo
echo "== Latest messages =="
psql_exec -c "
select id,
       created_at,
       peer_name,
       left(regexp_replace(content, E'[\\n\\r]+', ' ', 'g'), 180) as content_preview,
       token_count
from messages
order by id desc
limit 12;
"

echo
echo "== Queue =="
psql_exec -c "
select id,
       task_type,
       processed,
       created_at,
       message_id,
       left(coalesce(error, ''), 180) as error
from queue
order by id desc
limit 20;
"
