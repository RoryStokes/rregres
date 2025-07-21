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
        CASE WHEN (rule).interval IS NULL THEN '' ELSE 'interval=' || (rule).interval || ' ' END ||
        CASE WHEN (rule).day_of_month IS NULL THEN '' ELSE 'day_of_month=' || (rule).day_of_month || ' ' END
$$;

CREATE CAST (rrule_compound AS TEXT)
    WITH FUNCTION rrule_to_string(rrule_compound)
    AS IMPLICIT;