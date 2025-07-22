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
    days_with_numbers text[];
    days text[];
    occurrence_within_month int;
    months text[];
    start_date date;
    end_date date;
    date_range daterange;
    interval int;
    freq rrule_freq;
    subsequent_day TEXT;
    days_of_month_flags_from_start int DEFAULT 0;
    days_of_month_flags_from_end int DEFAULT 0;
BEGIN
    FOR line IN (SELECT unnest(string_to_array(rrule_string, E'\n'))) LOOP
        SELECT split_part(line, ':', 2) INTO content;
        IF starts_with(line, 'DTSTART') THEN
            SELECT to_date(split_part(content, 'T',1), 'YYYYMMDD') INTO start_date;
        ELSIF starts_with(line, 'RRULE') THEN
            SELECT jsonb_object_agg(split_part(part,'=',1), split_part(part,'=',2)) FROM (
                SELECT string_to_table(content, ';') as part
            ) INTO details;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'details %', details;
    IF details->>'WKST' IS NOT NULL AND details->>'WKST' != 'SU' THEN
        RAISE WARNING 'Weeks starting on any day other than Sunday is not yet supported - this flag is ignored' USING ERRCODE = 'data_exception';
    END IF;

    IF details->>'UNTIL' IS NOT NULL THEN
        SELECT to_date(split_part(content, 'T',1), 'YYYYMMDD') INTO end_date; 
    END IF;

    IF details->>'BYDAY' IS NOT NULL THEN
        SELECT string_to_array(details->>'BYDAY', ',') INTO days_with_numbers; 
        SELECT array_agg(right(unnest, 2)) FROM unnest(days_with_numbers) INTO days;
    END IF;

    IF details->>'BYMONTHDAY' IS NOT NULL THEN
        SELECT coalesce(sum(distinct(bit_flag)), 0) FROM (
            SELECT 1 << (day_number::int - 1) as bit_flag FROM
                unnest(string_to_array(details->>'BYMONTHDAY',',')) day_number
                WHERE day_number::int > 0
        ) INTO days_of_month_flags_from_start;

        SELECT coalesce(sum(distinct(bit_flag)), 0) FROM (
            SELECT 1 << (-1 - day_number::int) as bit_flag FROM
                unnest(string_to_array(details->>'BYMONTHDAY',',')) day_number
                WHERE day_number::int < 0
        ) INTO days_of_month_flags_from_end;
    ELSIF days_with_numbers IS NOT NULL THEN
        IF length(days_with_numbers[1]) > 2 THEN
            SELECT left(days_with_numbers[1], -2)::int INTO occurrence_within_month;
            FOR subsequent_day IN (SELECT unnest(days_with_numbers[2:])) LOOP
                IF NOT starts_with(subsequent_day, occurrence_within_month::text) THEN
                    RAISE EXCEPTION 'This library only supports the same numbered day in BYDAY on all days (expected prefix of [%], got [%])', occurrence_within_month, subsequent_day;
                END IF;
            END LOOP;
        ELSE
            FOR subsequent_day IN (SELECT unnest(days_with_numbers[2:])) LOOP
                IF length(subsequent_day) > 2 THEN
                    RAISE EXCEPTION 'This library only supports the same numbered day in BYDAY on all days (expected no number, got [%])', subsequent_day;
                END IF;
            END LOOP;
        END IF;
    END IF;

    IF occurrence_within_month > 0 THEN
        -- '011111111' represents the first week of the month, which we then bit shift to the appropriate week
        SELECT '01111111'::bit(8)::int << ((occurrence_within_month - 1) * 7) INTO days_of_month_flags_from_start;
        SELECT 0 INTO days_of_month_flags_from_end;
    ELSIF occurrence_within_month < 0 THEN
        -- '011111111' represents the last week of the month, which we then bit shift to the appropriate week
        SELECT '01111111'::bit(8)::int << ((-1 - occurrence_within_month) * 7) INTO days_of_month_flags_from_end;
        SELECT 0 INTO days_of_month_flags_from_start;
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
        days_of_month_flags_from_start,
        days_of_month_flags_from_end,
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
