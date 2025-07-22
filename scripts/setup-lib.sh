#!/bin/bash
set -eou pipefail

echo "Testing db readiness..."
until psql -U postgres -c "SELECT true"; do
    sleep 1;
done

psql -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'rregres' AND leader_pid IS NULL;"
dropdb --if-exists rregres
createdb rregres

for script in src/*.sql; do
    psql -U postgres -v ON_ERROR_STOP=1 -d rregres -f $script;
done

mkdir --parents .task_status
touch .task_status/lib-setup