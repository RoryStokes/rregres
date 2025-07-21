FROM postgres:17.5-bullseye

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    pgtap \
    && rm -rf /var/lib/apt/lists/*

COPY ./initdb.sql /docker-entrypoint-initdb.d
