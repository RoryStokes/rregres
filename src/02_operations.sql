CREATE OR REPLACE FUNCTION weekday_match(
    rule rrule,
    day int
) RETURNS BOOLEAN LANGUAGE SQL IMMUTABLE AS $$
    SELECT
        (day != 0 OR rule.su) AND
        (day != 1 OR rule.mo) AND
        (day != 2 OR rule.tu) AND
        (day != 3 OR rule.we) AND
        (day != 4 OR rule.th) AND
        (day != 5 OR rule.fr) AND
        (day != 6 OR rule.sa);
$$;

CREATE OR REPLACE FUNCTION month_match(
    rule rrule,
    month int
) RETURNS BOOLEAN LANGUAGE SQL IMMUTABLE AS $$
    SELECT
        (month != 1 OR rule.jan) AND
        (month != 2 OR rule.feb) AND
        (month != 3 OR rule.mar) AND
        (month != 4 OR rule.apr) AND
        (month != 5 OR rule.may) AND
        (month != 6 OR rule.jun) AND
        (month != 7 OR rule.jul) AND
        (month != 8 OR rule.aug) AND
        (month != 9 OR rule.sep) AND
        (month != 10 OR rule.oct) AND
        (month != 11 OR rule.nov) AND
        (month != 12 OR rule.dec);
$$;

CREATE OR REPLACE FUNCTION epoch_interval_number(
    freq rrule_freq,
    date date
) RETURNS int LANGUAGE SQL IMMUTABLE AS $$
    SELECT CASE
        WHEN freq = 'DAILY' THEN
            EXTRACT(epoch FROM date)::bigint / 86400
        WHEN freq = 'WEEKLY' THEN
            -- 1st Jan 1970 is a Thursday, so we add offset back to the start of that week
            -- (Monday 29th December, 1969)
            (EXTRACT(epoch FROM date)::bigint + 259200) / 604800
        WHEN freq = 'MONTHLY' THEN
            EXTRACT(year FROM date)::int * 12 + EXTRACT(month FROM date) - 1 
        WHEN freq = 'YEARLY' THEN
            EXTRACT(year FROM date)::int
    END
$$;

CREATE OR REPLACE FUNCTION days_from_end_of_month(
    date DATE
) RETURNS int LANGUAGE SQL IMMUTABLE AS $$
    SELECT EXTRACT(
        days from (date_trunc('month', date) + interval '1 month - 1 day' - date)
    )
$$;

CREATE OR REPLACE FUNCTION rrule_matches_date(
    rule rrule,
    date DATE
) RETURNS BOOLEAN LANGUAGE SQL IMMUTABLE AS $$
    SELECT rule.date_range @> date AND
        (
            NOT rule.by_weekday OR weekday_match(rule, EXTRACT(dow FROM date)::int)
        ) AND (
            NOT rule.by_month OR month_match(rule, EXTRACT(month FROM date)::int)
        ) AND (
            (rule.days_of_month_flags_from_end = 0 AND rule.days_of_month_flags_from_start = 0) OR
            (rule.days_of_month_flags_from_start & (1 << (EXTRACT(day FROM date)::int - 1))) != 0 OR
            (rule.days_of_month_flags_from_end & (1 << days_from_end_of_month(date))) != 0
        ) AND (
            rule.interval IS NULL OR
            rule.interval = 1 OR
            epoch_interval_number(rule.freq, date) % rule.interval = rule.interval_offset
        )
$$;

CREATE OPERATOR @> (
    function = rrule_matches_date,
    leftarg = rrule,
    rightarg = DATE
);

CREATE OR REPLACE FUNCTION occurrences(
    rule rrule,
    from_date date,
    until_date date
) RETURNS setof date LANGUAGE SQL IMMUTABLE AS $$
    SELECT date FROM (
        SELECT generate_series::date as date
            FROM generate_series(from_date::timestamp, until_date::timestamp, '1 day'::interval)
    ) WHERE rule @> date
$$;

CREATE OR REPLACE FUNCTION next_occurrence(
    rule rrule,
    from_date date
) RETURNS date LANGUAGE SQL IMMUTABLE AS $$
    SELECT CASE
        WHEN from_date < lower((rule).date_range) THEN next_occurrence(rule, lower((rule).date_range))
        WHEN from_date > upper((rule).date_range) THEN NULL
        WHEN rule @> from_date THEN from_date
        ELSE next_occurrence(rule, (from_date + '1 day'::interval)::date)
    END
$$;

CREATE OR REPLACE FUNCTION next_n_occurrences(
    rule rrule,
    from_date date,
    n int
) RETURNS setof date
LANGUAGE SQL IMMUTABLE AS $$
    WITH RECURSIVE occurrence AS (
        SELECT 1 as i, next_occurrence(rule, from_date) as d
        UNION
        SELECT i + 1, next_occurrence(rule, (d + '1 day'::interval)::date) FROM occurrence WHERE i < n
    ) SELECT d FROM occurrence;
$$;

CREATE OR REPLACE FUNCTION restricted_to_date_range(
    rule rrule,
    date_range daterange
) RETURNS rrule
LANGUAGE SQL IMMUTABLE AS $$
    SELECT (
        (rule).freq,
        (rule).date_range * date_range,
        (rule).interval,
        (rule).interval_offset,
        (rule).days_of_month_flags_from_start,
        (rule).days_of_month_flags_from_end,
        (rule).by_weekday,
        (rule).su,
        (rule).mo,
        (rule).tu,
        (rule).we,
        (rule).th,
        (rule).fr,
        (rule).sa,
        (rule).by_month,
        (rule).jan,
        (rule).feb,
        (rule).mar,
        (rule).apr,
        (rule).may,
        (rule).jun,
        (rule).jul,
        (rule).aug,
        (rule).sep,
        (rule).oct,
        (rule).nov,
        (rule).dec
    )
$$;

CREATE OPERATOR * (
    function = restricted_to_date_range,
    leftarg = rrule,
    rightarg = daterange
);

CREATE OR REPLACE FUNCTION weekdays_subset(
    a rrule,
    b rrule
) RETURNS BOOLEAN LANGUAGE SQL IMMUTABLE AS $$
    SELECT NOT (b).by_weekday OR (
        (a).by_weekday AND
        (NOT (a).su OR (b).su) AND
        (NOT (a).mo OR (b).mo) AND
        (NOT (a).tu OR (b).tu) AND
        (NOT (a).we OR (b).we) AND
        (NOT (a).th OR (b).th) AND
        (NOT (a).fr OR (b).fr) AND
        (NOT (a).sa OR (b).sa)
    )
$$;

CREATE OR REPLACE FUNCTION months_subset(
    a rrule,
    b rrule
) RETURNS BOOLEAN LANGUAGE SQL IMMUTABLE AS $$
    SELECT NOT (b).by_month OR (
        (a).by_month AND
        (NOT (a).jan OR (b).jan) AND
        (NOT (a).feb OR (b).feb) AND
        (NOT (a).mar OR (b).mar) AND
        (NOT (a).apr OR (b).apr) AND
        (NOT (a).may OR (b).may) AND
        (NOT (a).jun OR (b).jun) AND
        (NOT (a).jul OR (b).jul) AND
        (NOT (a).aug OR (b).aug) AND
        (NOT (a).sep OR (b).sep) AND
        (NOT (a).oct OR (b).oct) AND
        (NOT (a).nov OR (b).nov) AND
        (NOT (a).dec OR (b).dec)
    )
$$;

-- Bit subset check requires a and b to use the same from-start/from-end basis for a day;
-- a day expressed via a different basis in each rule (e.g. day 1 vs -31) is treated as
-- not provably contained, even in months where the two actually coincide.
CREATE OR REPLACE FUNCTION days_of_month_subset(
    a rrule,
    b rrule
) RETURNS BOOLEAN LANGUAGE SQL IMMUTABLE AS $$
    SELECT
        ((b).days_of_month_flags_from_start = 0 AND (b).days_of_month_flags_from_end = 0)
        OR (
            ((a).days_of_month_flags_from_start != 0 OR (a).days_of_month_flags_from_end != 0)
            AND ((a).days_of_month_flags_from_start & ~(b).days_of_month_flags_from_start) = 0
            AND ((a).days_of_month_flags_from_end & ~(b).days_of_month_flags_from_end) = 0
        )
$$;

-- a's allowed interval offsets are a subset of b's iff b's interval divides a's, and
-- a's offset reduces to b's offset modulo b's interval (subgroup-of-residues check)
CREATE OR REPLACE FUNCTION interval_subset(
    a rrule,
    b rrule
) RETURNS BOOLEAN LANGUAGE SQL IMMUTABLE AS $$
    SELECT
        (b).interval IS NULL OR (b).interval <= 1
        OR (
            (a).freq = (b).freq
            AND (a).interval IS NOT NULL AND (a).interval > 1
            AND (a).interval % (b).interval = 0
            AND (a).interval_offset % (b).interval = (b).interval_offset
        )
$$;

CREATE OR REPLACE FUNCTION rrule_contained_by(
    a rrule,
    b rrule
) RETURNS BOOLEAN LANGUAGE SQL IMMUTABLE AS $$
    SELECT
        (b).date_range @> (a).date_range
        AND weekdays_subset(a, b)
        AND months_subset(a, b)
        AND days_of_month_subset(a, b)
        AND interval_subset(a, b)
$$;

-- rule_a <@ rule_b: every occurrence of rule_a is also an occurrence of rule_b.
-- Proven structurally from the rule fields, so it holds for unbounded rules too;
-- it is sound but not complete (see days_of_month_subset), so a false result
-- does not prove non-containment.
CREATE OPERATOR <@ (
    function = rrule_contained_by,
    leftarg = rrule,
    rightarg = rrule
);

CREATE OR REPLACE FUNCTION rrule_contains(
    a rrule,
    b rrule
) RETURNS BOOLEAN LANGUAGE SQL IMMUTABLE AS $$
    SELECT rrule_contained_by(b, a)
$$;

CREATE OPERATOR @> (
    function = rrule_contains,
    leftarg = rrule,
    rightarg = rrule
);

-- Structural (non-enumerative) proof that rule's weekday/month grid is covered by the
-- union of covering_rules, restricted to covering rules that individually span all of
-- rule's date_range and carry no INTERVAL or day-of-month restriction of their own -
-- i.e. rules whose only filtering effect is on weekday/month. Under that restriction, a
-- date's coverage depends only on its (weekday, month) pair, so this checks all 84 such
-- pairs instead of walking real calendar dates. It is sound but not complete: covering
-- rules that only combine via date_range (e.g. Jan-Jun / Jul-Dec split) or that mix
-- INTERVAL/day-of-month restrictions across the set fall through to a false result here
-- and are left to the exact but date-walking rrule_is_covered_by fallback.
CREATE OR REPLACE FUNCTION rrule_grid_covered_by(
    rule rrule,
    covering_rules rrule[]
) RETURNS BOOLEAN LANGUAGE SQL IMMUTABLE AS $$
    WITH qualifying AS (
        SELECT covering_rule FROM unnest(covering_rules) covering_rule
        WHERE (covering_rule).date_range @> (rule).date_range
          AND ((covering_rule).interval IS NULL OR (covering_rule).interval <= 1)
          AND (covering_rule).days_of_month_flags_from_start = 0
          AND (covering_rule).days_of_month_flags_from_end = 0
    )
    SELECT NOT EXISTS (
        SELECT 1
        FROM generate_series(0,6) weekday
        CROSS JOIN generate_series(1,12) month
        WHERE (NOT (rule).by_weekday OR weekday_match(rule, weekday))
          AND (NOT (rule).by_month OR month_match(rule, month))
          AND NOT EXISTS (
              SELECT 1 FROM qualifying
              WHERE (NOT (qualifying.covering_rule).by_weekday OR weekday_match(qualifying.covering_rule, weekday))
                AND (NOT (qualifying.covering_rule).by_month OR month_match(qualifying.covering_rule, month))
          )
    )
$$;

-- Whether every occurrence of `rule` within [from_date, until_date] is matched by at
-- least one rule in `covering_rules`. Unlike <@, this proves coverage that only
-- emerges from combining multiple covering rules. Tries two structural (non-enumerative)
-- checks first - rrule_contained_by against any single covering rule, then the grid
-- check above - and only walks real occurrences within the given window if neither can
-- prove coverage; the enumerative fallback is not a statement about occurrences outside
-- that window.
CREATE OR REPLACE FUNCTION rrule_is_covered_by(
    rule rrule,
    covering_rules rrule[],
    from_date date,
    until_date date
) RETURNS BOOLEAN LANGUAGE SQL IMMUTABLE AS $$
    SELECT
        rule <@ ANY(covering_rules)
        OR rrule_grid_covered_by(rule, covering_rules)
        OR NOT EXISTS (
            SELECT 1
            FROM occurrences(rule, from_date, until_date) occurrence_date
            WHERE NOT EXISTS (
                SELECT 1 FROM unnest(covering_rules) covering_rule
                WHERE covering_rule @> occurrence_date
            )
        )
$$;
