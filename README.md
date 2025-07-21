# rregres

> [!IMPORTANT]  
> This is in a very early stage of development, and is likely to contain logical errors

A performant, opinionated postgres library to express a recurring pattern of dates, supporting a limited subset of the [iCalendar Recurrence Rule](https://icalendar.org/iCalendar-RFC-5545/3-8-5-3-recurrence-rule.html) features.

In particular, this library only supports dates (ignoring times and time zones) and does not natively support exceptions to the patterns. It is optimised to be able to query a large set of rules to see which will occur on a given date.

## Examples

```sql
rregres=# SELECT from_rrule_string('RRULE:FREQ=WEEKLY;BYDAY=MO') @> '2025-07-21';
 ?column?
----------
 t
(1 row)

rregres=# SELECT from_rrule_string('RRULE:FREQ=WEEKLY;BYDAY=MO') @> '2025-07-22';
 ?column?
----------
 f
(1 row)
rregres=# SELECT occurrences(from_rrule_string('RRULE:FREQ=WEEKLY;BYDAY=MO'), '2025-07-01', '2025-08-01');
 occurrences
-------------
 2025-07-07
 2025-07-14
 2025-07-21
 2025-07-28
(4 rows)
```

## Performance
Testing on a set of 1 million randomly generated weekly recurrence rules to show query optimisation and performance. Result takes under 0.4 seconds to count the rules that match a specific date - the target is to keep this number below 1 second as functionality is expanded and logic is confirmed.

```sql
CREATE TABLE test(
    name TEXT,
    rrule rrule
);

INSERT INTO test(name, rrule) SELECT
    'Test '||i,
    ('WEEKLY','(,)', interval, FLOOR(random() * interval), NULL, True, su,mo,tu,we,th,fr,sa,False,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL)::rrule
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

EXPLAIN ANALYSE SELECT count(*) FROM test WHERE rrule @> '2025-07-22';
```
Result:
```
 Aggregate  (cost=49846.11..49846.12 rows=1 width=8) (actual time=314.181..314.182 rows=1 loops=1)
   ->  Seq Scan on test  (cost=0.00..49846.00 rows=42 width=0) (actual time=0.011..308.623 rows=203687 loops=1)
         Filter: (((NOT (rrule).by_weekday) OR (rrule).tu) AND ((NOT (rrule).by_month) OR (rrule).jul) AND ((rrule).date_range @> '2025-07-22'::date) AND (((rrule).freq <> 'MONTHLY'::rrule_freq) OR (22 = (rrule).day_of_month)) AND (((rrule)."interval" IS NULL) OR ((rrule)."interval" = 1) OR ((((1753142400 + CASE WHEN ((rrule).freq = 'WEEKLY'::rrule_freq) THEN 345600 ELSE 0 END) / CASE WHEN ((rrule).freq = 'DAILY'::rrule_freq) THEN 86400 WHEN ((rrule).freq = 'WEEKLY'::rrule_freq) THEN 604800 ELSE 2628000 END) % (rrule)."interval") = (rrule).interval_offset)))
         Rows Removed by Filter: 796313
 Planning Time: 0.211 ms
 Execution Time: 314.200 ms
(6 rows)
```