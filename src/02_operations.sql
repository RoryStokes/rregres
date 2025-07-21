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
    SELECT
        (
            EXTRACT(epoch FROM date)::int
            -- 1st Jan 1970 is a Thursday, so we add offset back to the start of that week
            + (CASE WHEN freq = 'WEEKLY' THEN 345600 ELSE 0 END) 
        ) / (
            CASE
                WHEN freq = 'DAILY' THEN 86400
                WHEN freq = 'WEEKLY' THEN 604800 
                ELSE 2628000 END
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
            NOT rule.freq = 'MONTHLY' OR EXTRACT(day FROM date)::int = rule.day_of_month
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
