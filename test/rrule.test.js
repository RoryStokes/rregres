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

describe("rrule containment (<@ / @>)", () => {
  const containmentCases = [
    {
      label: "a weekday is contained within a set of weekdays",
      a: "RRULE:FREQ=WEEKLY;BYDAY=MO",
      b: "RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR",
      expected: true,
    },
    {
      label: "a set of weekdays is not contained within a single weekday",
      a: "RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR",
      b: "RRULE:FREQ=WEEKLY;BYDAY=MO",
      expected: false,
    },
    {
      label: "every 4th week is contained within every 2nd week at the same offset",
      a: "RRULE:FREQ=WEEKLY;INTERVAL=4",
      b: "RRULE:FREQ=WEEKLY;INTERVAL=2",
      expected: true,
    },
    {
      label: "every 2nd week is not contained within every 4th week",
      a: "RRULE:FREQ=WEEKLY;INTERVAL=2",
      b: "RRULE:FREQ=WEEKLY;INTERVAL=4",
      expected: false,
    },
    {
      label: "a monthday is contained within a superset of monthdays",
      a: "RRULE:FREQ=MONTHLY;BYMONTHDAY=1",
      b: "RRULE:FREQ=MONTHLY;BYMONTHDAY=1,15",
      expected: true,
    },
    {
      label: "a set of monthdays is not contained within a single monthday",
      a: "RRULE:FREQ=MONTHLY;BYMONTHDAY=1,15",
      b: "RRULE:FREQ=MONTHLY;BYMONTHDAY=1",
      expected: false,
    },
    {
      label: "a month is contained within a superset of months",
      a: "RRULE:FREQ=YEARLY;BYMONTH=3",
      b: "RRULE:FREQ=YEARLY;BYMONTH=3,6,9,12",
      expected: true,
    },
    {
      label: "unrelated rules with the same weekday but mismatched interval offsets are not contained",
      a: "DTSTART:20230101T000000Z\nRRULE:FREQ=WEEKLY;INTERVAL=2",
      b: "DTSTART:20230102T000000Z\nRRULE:FREQ=WEEKLY;INTERVAL=2",
      expected: false,
    },
  ];

  test.each(containmentCases)("$label", async ({ a, b, expected }) => {
    const rruleA = a.includes("DTSTART") ? a : `DTSTART:20230101T000000Z\n${a}`;
    const rruleB = b.includes("DTSTART") ? b : `DTSTART:20230101T000000Z\n${b}`;

    const { rows } = await client.query(
      `SELECT
        (from_rrule_string($1::text) <@ from_rrule_string($2::text)) AS contained,
        (from_rrule_string($2::text) @> from_rrule_string($1::text)) AS contains`,
      [rruleA, rruleB]
    );

    expect(rows[0].contained).toBe(expected);
    expect(rows[0].contains).toBe(expected);
  });

  test.each(containmentCases)(
    "structural result for $label matches brute-force occurrence comparison",
    async ({ a, b }) => {
      const rruleA = a.includes("DTSTART") ? a : `DTSTART:20230101T000000Z\n${a}`;
      const rruleB = b.includes("DTSTART") ? b : `DTSTART:20230101T000000Z\n${b}`;

      const { rows } = await client.query(
        `SELECT
          (from_rrule_string($1::text) <@ from_rrule_string($2::text)) AS structural,
          NOT EXISTS (
            SELECT 1 FROM occurrences(from_rrule_string($1::text), $3::date, $4::date) d
            WHERE NOT (from_rrule_string($2::text) @> d)
          ) AS brute_force`,
        [rruleA, rruleB, "2023-01-01", "2024-12-31"]
      );

      expect(rows[0].structural).toEqual(rows[0].brute_force);
    }
  );

  test("a rule restricted to a bounded date range is contained within its unbounded parent", async () => {
    const { rows } = await client.query(
      `SELECT (
        from_rrule_string($1::text) <@ from_rrule_string($2::text)
      ) AS contained`,
      [
        "DTSTART:20230601T000000Z\nRRULE:FREQ=WEEKLY;BYDAY=MO;UNTIL=20230801T000000Z",
        "DTSTART:20230101T000000Z\nRRULE:FREQ=WEEKLY;BYDAY=MO",
      ]
    );

    expect(rows[0].contained).toBe(true);
  });
});

describe("rrule_is_covered_by", () => {
  test("occurrences covered by combining several non-containing rules", async () => {
    const { rows } = await client.query(
      `SELECT rrule_is_covered_by(
        from_rrule_string($1::text),
        ARRAY[from_rrule_string($2::text), from_rrule_string($3::text)],
        $4::date,
        $5::date
      ) AS covered`,
      [
        "DTSTART:20230101T000000Z\nRRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR",
        "DTSTART:20230101T000000Z\nRRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE",
        "DTSTART:20230101T000000Z\nRRULE:FREQ=WEEKLY;BYDAY=TH,FR",
        "2023-01-01",
        "2023-12-31",
      ]
    );

    expect(rows[0].covered).toBe(true);
  });

  test("occurrences not covered by an unrelated set of rules", async () => {
    const { rows } = await client.query(
      `SELECT rrule_is_covered_by(
        from_rrule_string($1::text),
        ARRAY[from_rrule_string($2::text)],
        $3::date,
        $4::date
      ) AS covered`,
      [
        "DTSTART:20230101T000000Z\nRRULE:FREQ=WEEKLY;BYDAY=SA",
        "DTSTART:20230101T000000Z\nRRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR",
        "2023-01-01",
        "2023-12-31",
      ]
    );

    expect(rows[0].covered).toBe(false);
  });

  test("an empty covering set fails when the rule has occurrences in range", async () => {
    const { rows } = await client.query(
      `SELECT rrule_is_covered_by(
        from_rrule_string($1::text),
        ARRAY[]::rrule[],
        $2::date,
        $3::date
      ) AS covered`,
      ["DTSTART:20230101T000000Z\nRRULE:FREQ=WEEKLY;BYDAY=MO", "2023-01-01", "2023-01-31"]
    );

    expect(rows[0].covered).toBe(false);
  });

  test("an empty covering set is vacuously true when the rule has no occurrences in range", async () => {
    const { rows } = await client.query(
      `SELECT rrule_is_covered_by(
        from_rrule_string($1::text),
        ARRAY[]::rrule[],
        $2::date,
        $3::date
      ) AS covered`,
      ["DTSTART:20230601T000000Z\nRRULE:FREQ=WEEKLY;BYDAY=MO", "2023-01-01", "2023-01-31"]
    );

    expect(rows[0].covered).toBe(true);
  });
});

describe("rrule_grid_covered_by (structural fast path for rrule_is_covered_by)", () => {
  test("proves a weekday split covers the full set without enumerating dates", async () => {
    const { rows } = await client.query(
      `SELECT rrule_grid_covered_by(
        from_rrule_string($1::text),
        ARRAY[from_rrule_string($2::text), from_rrule_string($3::text)]
      ) AS covered`,
      [
        "DTSTART:20230101T000000Z\nRRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR",
        "DTSTART:20230101T000000Z\nRRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE",
        "DTSTART:20230101T000000Z\nRRULE:FREQ=WEEKLY;BYDAY=TH,FR",
      ]
    );

    expect(rows[0].covered).toBe(true);
  });

  test("declines (rather than wrongly proves) coverage that only works because weekday and month combine per-rule", async () => {
    // BYDAY=MO alone and BYMONTH=1 alone do not, between them, cover BYDAY=TU;BYMONTH=2 -
    // a naive per-dimension union would wrongly think they do
    const { rows } = await client.query(
      `SELECT
        rrule_grid_covered_by(
          from_rrule_string($1::text),
          ARRAY[from_rrule_string($2::text), from_rrule_string($3::text)]
        ) AS grid_result,
        rrule_is_covered_by(
          from_rrule_string($1::text),
          ARRAY[from_rrule_string($2::text), from_rrule_string($3::text)],
          $4::date,
          $5::date
        ) AS full_result`,
      [
        "DTSTART:20230101T000000Z\nRRULE:FREQ=WEEKLY;BYDAY=TU;BYMONTH=2",
        "DTSTART:20230101T000000Z\nRRULE:FREQ=WEEKLY;BYDAY=MO",
        "DTSTART:20230101T000000Z\nRRULE:FREQ=WEEKLY;BYMONTH=1",
        "2023-01-01",
        "2023-12-31",
      ]
    );

    expect(rows[0].grid_result).toBe(false);
    expect(rows[0].full_result).toBe(false);
  });

  test("declines when a covering rule has its own INTERVAL restriction", async () => {
    const { rows } = await client.query(
      `SELECT rrule_grid_covered_by(
        from_rrule_string($1::text),
        ARRAY[from_rrule_string($2::text)]
      ) AS covered`,
      [
        "DTSTART:20230101T000000Z\nRRULE:FREQ=WEEKLY;BYDAY=MO",
        "DTSTART:20230101T000000Z\nRRULE:FREQ=WEEKLY;BYDAY=MO;INTERVAL=2",
      ]
    );

    expect(rows[0].covered).toBe(false);
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
