#!/bin/bash
psql -U postgres -d rregres << EOF
DROP TABLE test;

CREATE TABLE test(
    name TEXT,
    rrule rrule
);

INSERT INTO test(name, rrule) SELECT
    'Test '||i,
    ('WEEKLY','(,)', interval, FLOOR(random() * interval)::smallint, i, i, True, su,mo,tu,we,th,fr,sa,False,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL)::rrule
FROM (
    SELECT 
        generate_series as i,
        (random() > 0.5) as su,
        (random() > 0.5) as mo,
        (random() > 0.5) as tu,
        (random() > 0.5) as we,
        (random() > 0.5) as th,
        (random() > 0.5) as fr,
        (random() > 0.5) as sa,
        FLOOR(random() * 6)+1 as interval
    FROM generate_series(1,1000000)
);
EOF

touch .task_status/testdata-setup