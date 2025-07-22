#!/bin/bash
psql -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'rregres' AND leader_pid IS NULL;"
dropdb rregres
createdb rregres

for script in src/*.sql; do
    psql -U postgres -d rregres -f $script;
done
