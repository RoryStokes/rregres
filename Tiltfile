docker_compose("./docker-compose.yml")

label_infra="01_Infra"
label_setup="02_Setup"
label_tests="03_Tests"

dc_resource(
    "db",
    labels=[label_infra]
)

local_resource(
    "Library setup",
    cmd="./scripts/setup-lib.sh",
    deps=["./scripts/setup-lib.sh", "./src"],
    labels=[label_setup]
)

local_resource(
    "Test data setup",
    cmd="./scripts/setup-testdata.sh",
    deps=["./scripts/setup-testdata.sh", "./.task_status/lib-setup"],
    labels=[label_setup]
)

local_resource(
    "JS tests",
    dir="./test",
    cmd="npm run test .",
    deps=["./.task_status/lib-setup"],
    labels=[label_tests]
)

local_resource(
    "Performance test",
    cmd="./scripts/test-perf.sh",
    deps=["./scripts/test-perf.sh", "./.task_status/testdata-setup"],
    labels=[label_tests]
)