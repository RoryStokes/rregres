CREATE OR REPLACE FUNCTION rrule_to_string(
    rule rrule_compound
) RETURNS TEXT LANGUAGE SQL IMMUTABLE AS $$
    SELECT (rule).freq::text || ' ' ||
        CASE WHEN (rule).by_weekday THEN left(
            CASE WHEN (rule).su THEN 'su' || '|' ELSE '' END ||
            CASE WHEN (rule).mo THEN 'mo' || '|' ELSE '' END ||
            CASE WHEN (rule).tu THEN 'tu' || '|' ELSE '' END ||
            CASE WHEN (rule).we THEN 'we' || '|' ELSE '' END ||
            CASE WHEN (rule).th THEN 'th' || '|' ELSE '' END ||
            CASE WHEN (rule).fr THEN 'fr' || '|' ELSE '' END ||
            CASE WHEN (rule).sa THEN 'sa' || '|' ELSE '' END,
            -1
        ) || ' ' ELSE '' END ||
        CASE WHEN (rule).by_month THEN left(
            CASE WHEN (rule).jan THEN 'jan' || '|' ELSE '' END ||
            CASE WHEN (rule).feb THEN 'feb' || '|' ELSE '' END ||
            CASE WHEN (rule).mar THEN 'mar' || '|' ELSE '' END ||
            CASE WHEN (rule).apr THEN 'apr' || '|' ELSE '' END ||
            CASE WHEN (rule).may THEN 'may' || '|' ELSE '' END ||
            CASE WHEN (rule).jun THEN 'jun' || '|' ELSE '' END ||
            CASE WHEN (rule).jul THEN 'jul' || '|' ELSE '' END ||
            CASE WHEN (rule).aug THEN 'aug' || '|' ELSE '' END ||
            CASE WHEN (rule).sep THEN 'sep' || '|' ELSE '' END ||
            CASE WHEN (rule).oct THEN 'oct' || '|' ELSE '' END ||
            CASE WHEN (rule).nov THEN 'nov' || '|' ELSE '' END ||
            CASE WHEN (rule).dec THEN 'dec' || '|' ELSE '' END,
            -1
        ) || ' ' ELSE '' END ||
        (rule).date_range::text || ' ' ||
        CASE WHEN (rule).interval IS NULL THEN '' ELSE 'interval=' || (rule).interval || ' ' END
$$;

CREATE CAST (rrule_compound AS TEXT)
    WITH FUNCTION rrule_to_string(rrule_compound)
    AS IMPLICIT;

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
        'daysOfMonth', (SELECT CASE
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
            ) ELSE NULL END),
        'weekdays', (SELECT CASE WHEN (rule).by_weekday THEN (
            CASE WHEN (rule).su THEN '{SU}' ELSE '{}' END ||
            CASE WHEN (rule).mo THEN '{MO}' ELSE '{}' END ||
            CASE WHEN (rule).tu THEN '{TU}' ELSE '{}' END ||
            CASE WHEN (rule).we THEN '{WE}' ELSE '{}' END ||
            CASE WHEN (rule).th THEN '{TH}' ELSE '{}' END ||
            CASE WHEN (rule).fr THEN '{FR}' ELSE '{}' END ||
            CASE WHEN (rule).sa THEN '{SA}' ELSE '{}' END
        ) ELSE NULL END),
        'months', (SELECT CASE WHEN (rule).by_month THEN (
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
        ) ELSE NULL END)
    ));
END;
$$;
