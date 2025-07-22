#!/bin/bash
psql -U postgres -d rregres -c "EXPLAIN ANALYSE SELECT count(*) FROM test WHERE rrule @> '2025-07-21'";