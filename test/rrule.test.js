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
  "RRULE:FREQ=WEEKLY;BYDAY=MO,TU",
  "RRULE:FREQ=WEEKLY;BYDAY=FR;INTERVAL=2",
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
    label: "new year 23/25",
    from: "2023-12-25",
    to: "2024-01-10",
  },
  {
    label: "end of feb 24 (leap year)",
    from: "2024-02-25",
    to: "2024-03-10",
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

afterAll(() => {
  client.end();
});
