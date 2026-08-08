#!/bin/bash
psql -U postgres -d rregres << EOF
DROP TABLE test;

CREATE TABLE test(
    name TEXT,
    rrule rrule,
    rrule_string text,
    rruleset _rrule.rruleset
);

INSERT INTO test(name, rrule, rrule_string, rruleset) 
SELECT
    name,
    rrule,
    to_rrule_string(rrule),
    to_rrule_string(rrule)::_rrule.rruleset
FROM (
    SELECT
        'Test '||i as name,
        ('MONTHLY','(,)', interval, 1, 3, 1, True, su,mo,tu,we,th,fr,sa,False,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL)::rrule as rrule
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
        FROM generate_series(1,100000)
    )
);
EOF

touch .task_status/testdata-setup