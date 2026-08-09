const { rrulestr } = require("rrule");
const { Client } = require("pg");

const startDates = [
  "2023-01-01", // Sun
  "2023-01-02", // Mon
  "2023-01-03", // Tue
  "2023-01-04", // Wed
  "2023-01-05", // Thurs
  "2023-01-06", // Fri
  "2023-01-07", // Sat
  "2024-02-28", // Pre-leap day
  "2024-02-29", // Leap day
  "2023-02-28", // Non-leap day
];

const rulesToTest = [
  "RRULE:FREQ=MONTHLY;BYDAY=1MO,1FR",
  "RRULE:FREQ=MONTHLY;BYDAY=1FR,1SA;INTERVAL=3",
  "RRULE:FREQ=MONTHLY;BYDAY=-2MO,-2WE",
  "RRULE:FREQ=MONTHLY;BYDAY=-1FR;INTERVAL=2",
  "RRULE:FREQ=MONTHLY;BYMONTHDAY=1,-3",
  "RRULE:FREQ=MONTHLY;BYMONTHDAY=-2;INTERVAL=3",
  "RRULE:FREQ=MONTHLY;BYMONTHDAY=31",
  "RRULE:FREQ=MONTHLY;BYMONTHDAY=-1",
  "RRULE:FREQ=MONTHLY;BYMONTH=3,6,9,12;BYDAY=1MO",
  "RRULE:FREQ=WEEKLY;BYDAY=MO,TU",
  "RRULE:FREQ=WEEKLY;BYDAY=FR;INTERVAL=2",
  "RRULE:FREQ=WEEKLY;BYDAY=WE;INTERVAL=2;COUNT=6",
  "RRULE:FREQ=WEEKLY;BYDAY=WE;COUNT=6",
  "RRULE:FREQ=DAILY",
  "RRULE:FREQ=DAILY;INTERVAL=3",
  "RRULE:FREQ=YEARLY;BYMONTH=3;BYMONTHDAY=15",
  "RRULE:FREQ=YEARLY;BYMONTH=6;BYDAY=1MO",
];

const testDateRanges = [
  {
    label: "new year 22/23",
    from: "2022-12-25",
    to: "2023-01-10",
  },
  {
    label: "end of feb 23",
    from: "2023-02-25",
    to: "2023-03-10",
  },
  {
    label: "end of feb 24 (leap year)",
    from: "2024-02-25",
    to: "2024-03-10",
  },
  {
    label: "all of 2024 and 2025",
    from: "2024-01-01",
    to: "2026-01-01",
  },
];

const client = new Client({
  user: "postgres",
  database: "rregres",
});

beforeAll(() => {
  client.connect();
});

describe.each(rulesToTest)("for %s", (rule) => {
  describe.each(startDates)("starting on %s", (startDateString) => {
    const startDate = new Date(startDateString);
    const rruleString = `DTSTART:${startDate
      .toISOString()
      .replace(/[-:\.]/g, "")
      .substring(0, 15)}Z\n${rule}`;
    const rrule = rrulestr(rruleString);

    test.each(testDateRanges)(
      "for dates around $label",
      async ({ from, to }) => {
        // Calculating occurrences in db should give the same result
        const occurrencesFromJs = rrule
          .between(new Date(from), new Date(to), true)
          .map((d) => d.toISOString().split("T")[0]);

        const queryForOccurrences = await client.query(
          "SELECT occurrences(from_rrule_string($1::text), $2::date, $3::date)::text",
          [rruleString, from, to]
        );
        const occurrencesFromDb = queryForOccurrences.rows.map(
          (row) => row.occurrences
        );
        expect(occurrencesFromDb).toEqual(occurrencesFromJs);

        // And re-stringifying the rule should give an equivalent expression
        const queryForText = await client.query("SELECT $1::text", [
          rruleString,
        ]);
        const restringifiedRule = queryForText.rows[0].text;
        const occurrencesFromRoundTrippedRule = rrulestr(restringifiedRule)
          .between(new Date(from), new Date(to), true)
          .map((d) => d.toISOString().split("T")[0]);

        expect(occurrencesFromRoundTrippedRule).toEqual(occurrencesFromJs);
      }
    );
  });
});

describe("UNTIL", () => {
  const rule = "RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR;UNTIL=20230115T000000Z";
  const rruleString = "DTSTART:20230101T000000Z\n" + rule;
  const rrule = rrulestr(rruleString);

  test.each(testDateRanges)(
    "for dates around $label",
    async ({ from, to }) => {
      const occurrencesFromJs = rrule
        .between(new Date(from), new Date(to), true)
        .map((d) => d.toISOString().split("T")[0]);

      const queryForOccurrences = await client.query(
        "SELECT occurrences(from_rrule_string($1::text), $2::date, $3::date)::text",
        [rruleString, from, to]
      );
      const occurrencesFromDb = queryForOccurrences.rows.map(
        (row) => row.occurrences
      );
      expect(occurrencesFromDb).toEqual(occurrencesFromJs);

      const queryForText = await client.query("SELECT $1::text", [
        rruleString,
      ]);
      const restringifiedRule = queryForText.rows[0].text;
      const occurrencesFromRoundTrippedRule = rrulestr(restringifiedRule)
        .between(new Date(from), new Date(to), true)
        .map((d) => d.toISOString().split("T")[0]);

      expect(occurrencesFromRoundTrippedRule).toEqual(occurrencesFromJs);
    }
  );
});

describe("json (de)serialization", () => {
  const rulesToRoundTrip = [
    "RRULE:FREQ=MONTHLY;BYDAY=1MO,1FR",
    "RRULE:FREQ=MONTHLY;BYMONTHDAY=1,-3",
    "RRULE:FREQ=MONTHLY;BYMONTH=3,6,9,12;BYDAY=1MO",
    "RRULE:FREQ=WEEKLY;BYDAY=WE;COUNT=6",
    "RRULE:FREQ=DAILY;INTERVAL=3",
    "RRULE:FREQ=YEARLY;BYMONTH=3;BYMONTHDAY=15",
  ];

  test.each(rulesToRoundTrip)(
    "occurrences are unchanged after to_json/from_json for %s",
    async (rule) => {
      const rruleString = "DTSTART:20230101T000000Z\n" + rule;

      const { rows } = await client.query(
        `SELECT
          ARRAY(SELECT occurrences(from_rrule_string($1::text), $2::date, $3::date))::text[] AS direct,
          ARRAY(SELECT occurrences(from_json(to_json(from_rrule_string($1::text))), $2::date, $3::date))::text[] AS round_tripped`,
        [rruleString, "2023-01-01", "2025-12-31"]
      );

      expect(rows[0].round_tripped).toEqual(rows[0].direct);
    }
  );
});

describe("restricted_to_date_range operator (*)", () => {
  test("intersects occurrences with the given range", async () => {
    const rruleString =
      "DTSTART:20230101T000000Z\nRRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR";

    const { rows } = await client.query(
      `SELECT ARRAY(
        SELECT occurrences(
          from_rrule_string($1::text) * daterange($2::date, $3::date, '[]'),
          $2::date,
          $4::date
        )
      )::text[] AS restricted`,
      [rruleString, "2023-01-10", "2023-01-20", "2023-02-01"]
    );

    expect(rows[0].restricted).toEqual([
      "2023-01-11",
      "2023-01-13",
      "2023-01-16",
      "2023-01-18",
      "2023-01-20",
    ]);
  });
});

describe("validation", () => {
  test("rejects BYDAY entries with mismatched ordinals", async () => {
    await expect(
      client.query("SELECT from_rrule_string($1::text)", [
        "DTSTART:20230101T000000Z\nRRULE:FREQ=MONTHLY;BYDAY=1MO,2FR",
      ])
    ).rejects.toThrow();
  });

  test("does not reject a WKST other than MO, but ignores it", async () => {
    const { rows } = await client.query(
      "SELECT occurrences(from_rrule_string($1::text), $2::date, $3::date)::text",
      [
        "DTSTART:20230101T000000Z\nRRULE:FREQ=WEEKLY;BYDAY=MO;WKST=SU",
        "2023-01-01",
        "2023-01-31",
      ]
    );

    expect(rows.map((row) => row.occurrences)).toEqual([
      "2023-01-02",
      "2023-01-09",
      "2023-01-16",
      "2023-01-23",
      "2023-01-30",
    ]);
  });
});

afterAll(() => {
  client.end();
});
