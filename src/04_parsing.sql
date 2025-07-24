CREATE OR REPLACE FUNCTION construct_rrule(
    freq rrule_freq,
    date_range daterange,
    "interval" int,
    interval_offset int,
    days_of_month int[],
    weekdays text[],
    months int[]
)
RETURNS rrule
LANGUAGE plpgsql
AS $$
DECLARE
    subsequent_day TEXT;
    days_of_month_flags_from_start int DEFAULT 0;
    days_of_month_flags_from_end int DEFAULT 0;
BEGIN
    IF days_of_month IS NOT NULL THEN
        SELECT sum(distinct(bit_flag)) FROM (
            SELECT 1 << (day_number - 1) as bit_flag FROM
                unnest(days_of_month) day_number
                WHERE day_number > 0
        ) INTO days_of_month_flags_from_start;

        SELECT sum(distinct(bit_flag)) FROM (
            SELECT 1 << (-1 - day_number) as bit_flag FROM
                unnest(days_of_month) day_number
                WHERE day_number < 0
        ) INTO days_of_month_flags_from_end;
    END IF;

    RETURN (
        freq,
        date_range,
        interval,
        interval_offset,
        coalesce(days_of_month_flags_from_start, 0),
        coalesce(days_of_month_flags_from_end, 0),
        weekdays IS NOT NULL,
        'SU' = ANY(weekdays),
        'MO' = ANY(weekdays),
        'TU' = ANY(weekdays),
        'WE' = ANY(weekdays),
        'TH' = ANY(weekdays),
        'FR' = ANY(weekdays),
        'SA' = ANY(weekdays),
        months IS NOT NULL,
        1 = ANY(months),
        2 = ANY(months),
        3 = ANY(months),
        4 = ANY(months),
        5 = ANY(months),
        6 = ANY(months),
        7 = ANY(months),
        8 = ANY(months),
        9 = ANY(months),
        10 = ANY(months),
        11 = ANY(months),
        12 = ANY(months)
    );
END;
$$;

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
    months int[];
    start_date date;
    end_date date;
    date_range daterange;
    interval int;
    freq rrule_freq;
    subsequent_day TEXT;
    days_of_month int[];
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
    IF details->>'WKST' IS NOT NULL AND details->>'WKST' != 'MO' THEN
        RAISE WARNING 'Weeks starting on any day other than Monday is not yet supported - this flag is ignored' USING ERRCODE = 'data_exception';
    END IF;

    IF details->>'UNTIL' IS NOT NULL THEN
        SELECT to_date(split_part(content, 'T',1), 'YYYYMMDD') INTO end_date; 
    END IF;

    IF details->>'BYDAY' IS NOT NULL THEN
        SELECT string_to_array(details->>'BYDAY', ',') INTO days_with_numbers; 
        SELECT array_agg(right(unnest, 2)) FROM unnest(days_with_numbers) INTO days;
    END IF;

    IF details->>'BYMONTHDAY' IS NOT NULL THEN
        SELECT array_agg(day_number::int) FROM
            unnest(string_to_array(details->>'BYMONTHDAY',',')) day_number
            INTO days_of_month;
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
        
        IF occurrence_within_month > 0 THEN
            SELECT array_agg(day_number) FROM 
                generate_series(
                    7*(occurrence_within_month) - 6,
                    7*(occurrence_within_month)
                ) day_number INTO days_of_month;
        ELSIF occurrence_within_month < 0 THEN
            SELECT array_agg(day_number) FROM 
                generate_series(
                    7*(occurrence_within_month),
                    7*(occurrence_within_month) + 6
                ) day_number INTO days_of_month;
        END IF;
    END IF;

    IF details->>'BYMONTH' IS NOT NULL THEN
        SELECT string_to_array(details->>'BYMONTH', ',') INTO months; 
    END IF;

    SELECT daterange(start_date, end_date, '[)') INTO date_range;
    SELECT COALESCE((details->>'INTERVAL')::int, 1) INTO interval;
    SELECT (details->>'FREQ')::rrule_freq INTO freq;

    RETURN construct_rrule(
        freq,
        date_range,
        interval,
        CASE WHEN interval > 1 AND start_date IS NOT NULL
            THEN epoch_interval_number(freq, start_date) % interval
            ELSE 0
        END,
        days_of_month,
        days,
        months
    );
END;
$$;


CREATE OR REPLACE FUNCTION from_json(
    payload jsonb
)
RETURNS rrule
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN construct_rrule(
        (payload->>'freq')::rrule_freq,
        (payload->>'dateRange')::daterange,
        COALESCE((payload->'interval')::int, 1),
        (payload->'intervalOffset')::int,
        (SELECT array_agg(day::int) FROM jsonb_array_elements(payload->'daysOfMonth') day),
        (SELECT array_agg(weekday #>> '{}') FROM jsonb_array_elements(payload->'weekdays') weekday),
        (SELECT array_agg(month::int) FROM jsonb_array_elements(payload->'months') month)
    );
END;
$$;
