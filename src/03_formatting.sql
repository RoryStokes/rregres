CREATE OR REPLACE FUNCTION days_of_month(
    rule rrule_compound
)
RETURNS int[]
LANGUAGE SQL
AS $$
 SELECT CASE
    WHEN (rule).days_of_month_flags_from_start != 0 
    OR (rule).days_of_month_flags_from_end != 0 
    THEN (
        SELECT array_agg(day)
            FROM generate_series(1,31) day
            WHERE (rule).days_of_month_flags_from_start & (1 << (day - 1)) != 0
    ) || (
        SELECT array_agg(-day) 
            FROM generate_series(1,31) day
            WHERE (rule).days_of_month_flags_from_end & (1 << (day - 1)) != 0
    ) ELSE NULL END
$$;


CREATE OR REPLACE FUNCTION weekdays(
    rule rrule_compound
)
RETURNS text[]
LANGUAGE SQL
AS $$
    SELECT CASE WHEN (rule).by_weekday THEN (
        CASE WHEN (rule).su THEN '{SU}'::text[] ELSE '{}' END ||
        CASE WHEN (rule).mo THEN '{MO}'::text[] ELSE '{}' END ||
        CASE WHEN (rule).tu THEN '{TU}'::text[] ELSE '{}' END ||
        CASE WHEN (rule).we THEN '{WE}'::text[] ELSE '{}' END ||
        CASE WHEN (rule).th THEN '{TH}'::text[] ELSE '{}' END ||
        CASE WHEN (rule).fr THEN '{FR}'::text[] ELSE '{}' END ||
        CASE WHEN (rule).sa THEN '{SA}'::text[] ELSE '{}' END
    ) ELSE NULL END
$$;

CREATE OR REPLACE FUNCTION months(
    rule rrule_compound
)
RETURNS text[]
LANGUAGE SQL
AS $$
    SELECT CASE WHEN (rule).by_month THEN (
        CASE WHEN (rule).jan THEN '{1}'::int[] ELSE '{}' END ||
        CASE WHEN (rule).feb THEN '{2}'::int[] ELSE '{}' END ||
        CASE WHEN (rule).mar THEN '{3}'::int[] ELSE '{}' END ||
        CASE WHEN (rule).apr THEN '{4}'::int[] ELSE '{}' END ||
        CASE WHEN (rule).may THEN '{5}'::int[] ELSE '{}' END ||
        CASE WHEN (rule).jun THEN '{6}'::int[] ELSE '{}' END ||
        CASE WHEN (rule).jul THEN '{7}'::int[] ELSE '{}' END ||
        CASE WHEN (rule).aug THEN '{8}'::int[] ELSE '{}' END ||
        CASE WHEN (rule).sep THEN '{9}'::int[] ELSE '{}' END ||
        CASE WHEN (rule).oct THEN '{10}'::int[] ELSE '{}' END ||
        CASE WHEN (rule).nov THEN '{11}'::int[] ELSE '{}' END ||
        CASE WHEN (rule).dec THEN '{12}'::int[] ELSE '{}' END
    ) ELSE NULL END
$$;

CREATE OR REPLACE FUNCTION to_rrule_string(
    rule rrule_compound
)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
    json_payload jsonb;
BEGIN
    SELECT jsonb_strip_nulls(jsonb_build_object(
        'FREQ', (rule).freq,
        'UNTIL', to_char(upper((rule).date_range), 'YYYYMMDDT000000Z'),
        'INTERVAL', (rule).interval,
        'BYMONTHDAY', array_to_string(days_of_month(rule), ','),
        'BYDAY', array_to_string(weekdays(rule), ','),
        'BYMONTH', array_to_string(months(rule), ',')
    )) INTO json_payload;

    RETURN (CASE 
        WHEN lower((rule).date_range) IS NULL THEN ''
        ELSE 'DTSTART:' ||
            to_char(next_occurence(rule, lower((rule).date_range)), 'YYYYMMDDT000000Z') ||
            E'\n'
        END
    ) || 'RRULE:' || array_to_string((
        SELECT array_agg(key || '=' || (value #>> '{}')) FROM jsonb_each(json_payload)
    ), ';');
END;
$$;

CREATE OR REPLACE FUNCTION to_json(
    rule rrule_compound
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN jsonb_strip_nulls(jsonb_build_object(
        'freq', (rule).freq,
        'dateRange', (rule).date_range::text,
        'interval', (rule).interval,
        'intervalOffset', (rule).interval_offset,
        'daysOfMonth', days_of_month(rule),
        'weekdays', weekdays(rule),
        'months', months(rule)
    ));
END;
$$;
