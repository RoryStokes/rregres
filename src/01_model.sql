CREATE TYPE rrule_freq AS ENUM (
    'MONTHLY',
    'WEEKLY',
    'DAILY'
);

CREATE TYPE rrule_compound AS (
    freq rrule_freq,
    date_range daterange,
    interval int,
    -- offset is calculated based on interval and frequency, relative to UNIX epoch
    interval_offset int,
    -- treated as bit strings for days that an event can occur on
    -- if both are zero, any day of the month is valid
    -- otherwise from least to most significant, the bits represent if a day is permitted 
    days_of_month_flags_from_start int,
    days_of_month_flags_from_end int,
    -- restrict occurrences by day of week
    by_weekday BOOLEAN,
    su BOOLEAN,
    mo BOOLEAN,
    tu BOOLEAN,
    we BOOLEAN,
    th BOOLEAN,
    fr BOOLEAN,
    sa BOOLEAN,
    -- restrict occurrences by month of year
    by_month BOOLEAN,
    jan BOOLEAN,
    feb BOOLEAN,
    mar BOOLEAN,
    apr BOOLEAN,
    may BOOLEAN,
    jun BOOLEAN,
    jul BOOLEAN,
    aug BOOLEAN,
    sep BOOLEAN,
    oct BOOLEAN,
    nov BOOLEAN,
    dec BOOLEAN
);

CREATE OR REPLACE FUNCTION rrule_check_valid_weekdays(
    rule rrule_compound
) RETURNS BOOLEAN LANGUAGE SQL IMMUTABLE AS $$
    SELECT rule.by_weekday = false OR (
        rule.su IS NOT NULL AND
        rule.mo IS NOT NULL AND
        rule.tu IS NOT NULL AND
        rule.we IS NOT NULL AND
        rule.th IS NOT NULL AND
        rule.fr IS NOT NULL AND
        rule.sa IS NOT NULL
    )
$$;

CREATE OR REPLACE FUNCTION rrule_check_valid_months(
    rule rrule_compound
) RETURNS BOOLEAN LANGUAGE SQL IMMUTABLE AS $$
    SELECT rule.by_month = false OR (
    rule.jan IS NOT NULL AND
    rule.feb IS NOT NULL AND
    rule.mar IS NOT NULL AND
    rule.apr IS NOT NULL AND
    rule.may IS NOT NULL AND
    rule.jun IS NOT NULL AND
    rule.jul IS NOT NULL AND
    rule.aug IS NOT NULL AND
    rule.sep IS NOT NULL AND
    rule.oct IS NOT NULL AND
    rule.nov IS NOT NULL AND
    rule.dec IS NOT NULL
    )
$$;

CREATE DOMAIN rrule AS rrule_compound
    CONSTRAINT freq_not_null CHECK ((VALUE).freq IS NOT NULL)
    CONSTRAINT date_range_not_null CHECK ((VALUE).date_range IS NOT NULL)
    CONSTRAINT by_weekday_not_null CHECK ((VALUE).by_weekday IS NOT NULL)
    CONSTRAINT by_month_not_null CHECK ((VALUE).by_month IS NOT NULL)
    CONSTRAINT days_of_month_flags_from_start_not_null CHECK ((VALUE).days_of_month_flags_from_start IS NOT NULL)
    CONSTRAINT days_of_month_flags_from_end_not_null CHECK ((VALUE).days_of_month_flags_from_end IS NOT NULL)
    CONSTRAINT by_weekday_false_or_weekdays_not_null CHECK (rrule_check_valid_weekdays(VALUE))
    CONSTRAINT by_month_false_or_months_not_null CHECK (rrule_check_valid_months(VALUE));
