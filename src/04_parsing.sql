CREATE OR REPLACE FUNCTION from_rrule_string(
    rrule_string TEXT
)
RETURNS rrule
LANGUAGE plpgsql
AS $$
DECLARE
    line text;
    content text;
    details jsonb;
    days text[];
    months text[];
    start_date date;
    end_date date;
    date_range daterange;
    interval int;
    freq rrule_freq;
BEGIN
    FOR line IN (SELECT unnest(string_to_array(rrule_string, E'\n'))) LOOP
        RAISE NOTICE 'line %', line;
        SELECT split_part(line, ':', 2) INTO content;
        IF starts_with(line, 'DTSTART') THEN
            SELECT to_date(split_part(content, 'T',1), 'YYYYMMDD') INTO start_date;
        ELSIF starts_with(line, 'RRULE') THEN
            SELECT jsonb_object_agg(split_part(part,'=',1), split_part(part,'=',2)) FROM (
                SELECT string_to_table(content, ';') as part
            ) INTO details;
        END IF;
    END LOOP;
    IF details->>'WKST' IS NOT NULL AND details->>'WKST' != 'SU' THEN
        RAISE WARNING 'Weeks starting on any day other than Sunday is not yet supported - this flag is ignored' USING ERRCODE = 'data_exception';
    END IF;

    IF details->>'UNTIL' IS NOT NULL THEN
        SELECT to_date(split_part(content, 'T',1), 'YYYYMMDD') INTO end_date; 
    END IF;

    IF details->>'BYDAY' IS NOT NULL THEN
        SELECT string_to_array(details->>'BYDAY', ',') INTO days; 
    END IF;

    IF details->>'BYMONTH' IS NOT NULL THEN
        SELECT string_to_array(details->>'BYMONTH', ',') INTO months; 
    END IF;

    SELECT daterange(start_date, end_date, '[)') INTO date_range;
    SELECT COALESCE((details->>'INTERVAL')::int, 1) INTO interval;

    IF details->>'FREQ' = 'YEARLY' THEN
        SELECT interval * 12 INTO interval;
        SELECT 'MONTHLY' INTO freq;
    ELSE
        SELECT (details->>'FREQ')::rrule_freq INTO freq;
    END IF;


    RETURN (
        freq,
        date_range,
        interval,
        CASE WHEN interval > 1 AND start_date IS NOT NULL
            THEN epoch_interval_number(freq, start_date) % interval
            ELSE 0
        END,
        CASE WHEN freq = 'MONTHLY' AND start_date IS NOT NULL
            THEN EXTRACT(day FROM start_date)::int
            ELSE NULL
        END,
        days IS NOT NULL,
        'SU' = ANY(days),
        'MO' = ANY(days),
        'TU' = ANY(days),
        'WE' = ANY(days),
        'TH' = ANY(days),
        'FR' = ANY(days),
        'SA' = ANY(days),
        months IS NOT NULL,
        '1' = ANY(days),
        '2' = ANY(days),
        '3' = ANY(days),
        '4' = ANY(days),
        '5' = ANY(days),
        '6' = ANY(days),
        '7' = ANY(days),
        '8' = ANY(days),
        '9' = ANY(days),
        '10' = ANY(days),
        '11' = ANY(days),
        '12' = ANY(days)
    );
END;
$$;





-- 'DTSTART;TZID=America/New_York:19970902T090000  RRULE:FREQ=WEEKLY;INTERVAL=2;WKST=SU'
-- 'RRULE:FREQ=WEEKLY;BYDAY=MO'

-- SELECT split_part(part,'=',1), split_part(part,'=',2) FROM (
--     SELECT string_to_table('FREQ=WEEKLY;INTERVAL=2;WKST=SU', ';') as part
-- );