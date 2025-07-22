DROP TABLE test;

CREATE TABLE test(
    name TEXT,
    rrule rrule
);


INSERT INTO test(name, rrule) SELECT
    'Test '||i,
    ('WEEKLY','(,)', interval, FLOOR(random() * interval)::smallint, NULL, True, su,mo,tu,we,th,fr,sa,False,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL)::rrule
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

DROP TABLE test;

CREATE TABLE test(
    name TEXT,
    month_int int,
    month_reverse_int int,
    month_arr int[],
    month_json jsonb
);


INSERT INTO test(name, month_int, month_reverse_int, month_arr, month_json) SELECT
    'Test '||i,
    month_int,
    month_reverse_int,
    ARRAY(
        SELECT generate_series + 1 
        FROM generate_series(0,30)
        WHERE (month_int::int >> generate_series::int) & 1
    ),
    '{}'
FROM (
    SELECT
        generate_series as i,
        floor(random() * 2147483647) as month_int,
        floor(random() * 2147483647) as month_reverse_int
    FROM generate_series(1,100)
);
