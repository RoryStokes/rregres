docker_build(
    "rregres",
    "./docker"
)

docker_compose("./docker-compose.yml")

local_resource("setup", cmd="./setup.sh", deps=['./setup.sh', './src'])