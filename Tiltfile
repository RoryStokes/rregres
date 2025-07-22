docker_build(
    "rregres",
    "./docker"
)

docker_compose("./docker-compose.yml")

local_resource("setup", cmd="./setup.sh", deps=['./setup.sh', './src'])
local_resource("test", dir="./test", cmd="npm run test .")