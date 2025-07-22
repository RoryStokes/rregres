#!/bin/bash
psql -U postgres -d rregres \
    -ac "EXPLAIN ANALYSE SELECT count(*) FROM test WHERE rrule @> '2025-07-21'" | tee .task_status/performance;

execution_millis=$(sed -nE 's/Execution Time:\s+([0-9]+)\.[0-9]+ ms/\1/p' < .task_status/performance)
target_millis=500

if [ "$execution_millis" -gt 500 ]; then
    echo "Query execution over 1M rows took over [$target_millis] ms"
    exit 1
fi
