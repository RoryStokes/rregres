## Model
```sql
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
    arr,
    (SELECT json_object_agg(unnest, True) FROM unnest(arr))
FROM (
    SELECT *, ARRAY(
        SELECT generate_series + 1 
        FROM generate_series(0,27)
        WHERE (month_int::int >> generate_series::int) & 1 = 1
    ) || ARRAY(
        SELECT -(generate_series + 1) 
        FROM generate_series(0,27)
        WHERE (month_reverse_int::int >> generate_series::int) & 1 = 1
    ) as arr FROM (
        SELECT
            generate_series as i,
            floor(random() * 2147483647) as month_int,
            floor(random() * 2147483647) as month_reverse_int
        FROM generate_series(1,1000000)
    )
);
```

## Performance

### Bitmasking ints
```
rregres=# EXPLAIN ANALYSE SELECT count(*) FROM test WHERE (month_int & (1 << 2)) != 0 OR (month_reverse_int & (1 << 3)) != 0;
                                                               QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------------
 Finalize Aggregate  (cost=70476.55..70476.56 rows=1 width=8) (actual time=60.868..64.056 rows=1 loops=1)
   ->  Gather  (cost=70476.34..70476.55 rows=2 width=8) (actual time=60.774..64.050 rows=3 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Partial Aggregate  (cost=69476.34..69476.35 rows=1 width=8) (actual time=49.430..49.430 rows=1 loops=3)
               ->  Parallel Seq Scan on test  (cost=0.00..68434.66 rows=416672 width=0) (actual time=0.101..42.283 rows=249742 loops=3)
                     Filter: (((month_int & 4) <> 0) OR ((month_reverse_int & 8) <> 0))
                     Rows Removed by Filter: 83592
 Planning Time: 0.053 ms
 Execution Time: 64.075 ms
```

### Array includes
```
rregres=# EXPLAIN ANALYSE SELECT count(*) FROM test WHERE 3 = ANY(month_arr) OR -4 = ANY(month_arr);
                                                               QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------------
 Finalize Aggregate  (cost=95212.70..95212.71 rows=1 width=8) (actual time=92.885..96.454 rows=1 loops=1)
   ->  Gather  (cost=95212.49..95212.70 rows=2 width=8) (actual time=92.779..96.447 rows=3 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Partial Aggregate  (cost=94212.49..94212.50 rows=1 width=8) (actual time=81.118..81.119 rows=1 loops=3)
               ->  Parallel Seq Scan on test  (cost=0.00..93435.63 rows=310741 width=0) (actual time=0.109..74.490 rows=249742 loops=3)
                     Filter: ((3 = ANY (month_arr)) OR ('-4'::integer = ANY (month_arr)))
                     Rows Removed by Filter: 83592
 Planning Time: 0.052 ms
 Execution Time: 96.478 ms
(10 rows)
```

### JSON keys
```
rregres=# EXPLAIN ANALYSE SELECT count(*) FROM test WHERE month_json ? '3' OR month_json ? '-4';
                                                               QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------------------------
 Finalize Aggregate  (cost=68101.52..68101.53 rows=1 width=8) (actual time=307.743..316.214 rows=1 loops=1)
   ->  Gather  (cost=68101.30..68101.51 rows=2 width=8) (actual time=307.657..316.208 rows=3 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Partial Aggregate  (cost=67101.30..67101.31 rows=1 width=8) (actual time=276.737..276.737 rows=1 loops=3)
               ->  Parallel Seq Scan on test  (cost=0.00..66351.24 rows=300024 width=0) (actual time=3.153..269.556 rows=249742 loops=3)
                     Filter: ((month_json ? '3'::text) OR (month_json ? '-4'::text))
                     Rows Removed by Filter: 83592
 Planning Time: 0.094 ms
 Execution Time: 316.237 ms
(10 rows)
```